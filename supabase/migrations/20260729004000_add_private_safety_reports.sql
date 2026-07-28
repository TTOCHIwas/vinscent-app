create table public.safety_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_user_id uuid not null
    references auth.users(id) on delete cascade,
  reported_user_id uuid
    references auth.users(id) on delete set null,
  couple_id uuid not null,
  target_type text not null,
  target_id text not null,
  reason text not null,
  details text,
  content_snapshot text,
  status text not null default 'pending',
  moderation_note text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint safety_reports_reporter_target_unique
    unique (reporter_user_id, target_type, target_id),
  constraint safety_reports_reported_user_check
    check (
      reported_user_id is null
      or reported_user_id <> reporter_user_id
    ),
  constraint safety_reports_target_type_check
    check (
      target_type in (
        'partner',
        'story_card',
        'question_answer',
        'recording',
        'calendar_event',
        'character',
        'ai_question',
        'ai_feedback',
        'ai_direct_answer',
        'ai_proactive_suggestion',
        'ai_memory'
      )
    ),
  constraint safety_reports_target_id_check
    check (char_length(btrim(target_id)) between 1 and 160),
  constraint safety_reports_reason_check
    check (
      reason in (
        'inappropriate',
        'harassment',
        'privacy',
        'spam',
        'unsafe_ai',
        'other'
      )
    ),
  constraint safety_reports_details_check
    check (
      details is null
      or char_length(details) between 1 and 1000
    ),
  constraint safety_reports_snapshot_check
    check (
      content_snapshot is null
      or char_length(content_snapshot) between 1 and 2000
    ),
  constraint safety_reports_status_check
    check (status in ('pending', 'reviewed', 'actioned', 'dismissed')),
  constraint safety_reports_moderation_note_check
    check (
      moderation_note is null
      or char_length(moderation_note) <= 2000
    )
);

create index safety_reports_moderation_queue_idx
  on public.safety_reports (status, created_at, id);

create index safety_reports_reported_user_idx
  on public.safety_reports (reported_user_id, created_at desc)
  where reported_user_id is not null;

alter table public.safety_reports enable row level security;

create trigger safety_reports_set_updated_at
  before update on public.safety_reports
  for each row
  execute function public.set_updated_at();

revoke all on table public.safety_reports
  from public, anon, authenticated;
grant all on table public.safety_reports to service_role;

create or replace function private.resolve_safety_report_target(
  requested_reporter_user_id uuid,
  requested_couple_id uuid,
  requested_partner_user_id uuid,
  requested_target_type text,
  requested_target_id text,
  requested_content_snapshot text
)
returns table (
  reported_user_id uuid,
  content_snapshot text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_uuid uuid;
  normalized_snapshot text := nullif(btrim(requested_content_snapshot), '');
begin
  if requested_target_type = 'partner' then
    if requested_target_id <> requested_partner_user_id::text then
      perform private.raise_app_error('safety_report_target_not_available');
    end if;

    return query
    select requested_partner_user_id, null::text;
    return;
  end if;

  if requested_target_type = 'ai_proactive_suggestion' then
    if normalized_snapshot is null then
      perform private.raise_app_error('safety_report_snapshot_required');
    end if;

    if char_length(normalized_snapshot) > 2000 then
      perform private.raise_app_error('safety_report_snapshot_too_long');
    end if;

    return query
    select null::uuid, normalized_snapshot;
    return;
  end if;

  begin
    target_uuid := requested_target_id::uuid;
  exception
    when invalid_text_representation then
      perform private.raise_app_error('safety_report_target_not_available');
  end;

  if requested_target_type = 'ai_direct_answer' then
    return query
    select null::uuid, aiuq.answer_text
    from public.ai_user_questions as aiuq
    where aiuq.id = target_uuid
      and aiuq.couple_id = requested_couple_id
      and aiuq.requester_user_id = requested_reporter_user_id
      and aiuq.status = 'completed';
  elsif requested_target_type = 'ai_question' then
    return query
    select null::uuid, q.question_text
    from public.daily_questions as dq
    join public.questions as q
      on q.id = dq.question_id
    where dq.id = target_uuid
      and dq.couple_id = requested_couple_id
      and q.source = 'ai';
  elsif requested_target_type = 'ai_feedback' then
    return query
    select null::uuid, aiqf.feedback_text
    from public.ai_question_feedbacks as aiqf
    where aiqf.daily_question_id = target_uuid
      and aiqf.couple_id = requested_couple_id
      and aiqf.state = 'published';
  elsif requested_target_type = 'ai_memory' then
    return query
    select null::uuid, aim.statement
    from public.ai_memories as aim
    where aim.id = target_uuid
      and aim.couple_id = requested_couple_id
      and aim.state in ('pending', 'active');
  else
    perform private.raise_app_error('invalid_safety_report_target_type');
  end if;

  if not found then
    perform private.raise_app_error('safety_report_target_not_available');
  end if;
end;
$$;

revoke execute on function private.resolve_safety_report_target(
  uuid,
  uuid,
  uuid,
  text,
  text,
  text
) from public, anon, authenticated;

create or replace function public.submit_safety_report(
  requested_target_type text,
  requested_target_id text,
  requested_reason text,
  requested_details text default null,
  requested_content_snapshot text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  partner_user_id uuid;
  normalized_target_type text := lower(btrim(requested_target_type));
  normalized_target_id text := btrim(requested_target_id);
  normalized_reason text := lower(btrim(requested_reason));
  normalized_details text := nullif(btrim(requested_details), '');
  target_context record;
  saved_report_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if normalized_target_type is null
    or normalized_target_type not in (
      'partner',
      'ai_question',
      'ai_feedback',
      'ai_direct_answer',
      'ai_proactive_suggestion',
      'ai_memory'
    )
  then
    perform private.raise_app_error('invalid_safety_report_target_type');
  end if;

  if normalized_target_id is null
    or char_length(normalized_target_id) not between 1 and 160
  then
    perform private.raise_app_error('invalid_safety_report_target');
  end if;

  if normalized_reason is null
    or normalized_reason not in (
      'inappropriate',
      'harassment',
      'privacy',
      'spam',
      'unsafe_ai',
      'other'
    )
  then
    perform private.raise_app_error('invalid_safety_report_reason');
  end if;

  if normalized_details is not null
    and char_length(normalized_details) > 1000
  then
    perform private.raise_app_error('safety_report_details_too_long');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  partner_user_id := case
    when active_couple.user_a_id = current_user_id
      then active_couple.user_b_id
    else active_couple.user_a_id
  end;

  select resolved.reported_user_id, resolved.content_snapshot
  into target_context
  from private.resolve_safety_report_target(
    current_user_id,
    active_couple.id,
    partner_user_id,
    normalized_target_type,
    normalized_target_id,
    requested_content_snapshot
  ) as resolved;

  if not found then
    perform private.raise_app_error('safety_report_target_not_available');
  end if;

  insert into public.safety_reports (
    reporter_user_id,
    reported_user_id,
    couple_id,
    target_type,
    target_id,
    reason,
    details,
    content_snapshot
  )
  values (
    current_user_id,
    target_context.reported_user_id,
    active_couple.id,
    normalized_target_type,
    normalized_target_id,
    normalized_reason,
    normalized_details,
    target_context.content_snapshot
  )
  on conflict (reporter_user_id, target_type, target_id)
  do update
  set reported_user_id = excluded.reported_user_id,
      couple_id = excluded.couple_id,
      reason = excluded.reason,
      details = excluded.details,
      content_snapshot = excluded.content_snapshot
  returning id into saved_report_id;

  return saved_report_id;
end;
$$;

revoke execute on function public.submit_safety_report(
  text,
  text,
  text,
  text,
  text
) from public, anon;
grant execute on function public.submit_safety_report(
  text,
  text,
  text,
  text,
  text
) to authenticated;
