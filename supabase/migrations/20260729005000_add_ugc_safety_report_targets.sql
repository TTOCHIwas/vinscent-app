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
    if requested_partner_user_id is null
      or requested_target_id <> requested_partner_user_id::text
    then
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

  if requested_target_type = 'story_card' then
    return query
    select
      slc.author_user_id,
      left(
        format(
          'date=%s; preview_path=%s; scene_data_path=%s',
          slc.couple_date,
          slc.preview_path,
          slc.scene_data_path
        ),
        2000
      )
    from public.story_loop_cards as slc
    where slc.id = target_uuid
      and slc.couple_id = requested_couple_id
      and slc.author_user_id = requested_partner_user_id;
  elsif requested_target_type = 'question_answer' then
    return query
    select dqa.user_id, dqa.answer_text
    from public.daily_question_answers as dqa
    join public.daily_questions as dq
      on dq.id = dqa.daily_question_id
    where dqa.id = target_uuid
      and dq.couple_id = requested_couple_id
      and dqa.user_id = requested_partner_user_id;
  elsif requested_target_type = 'recording' then
    return query
    select
      coalesce(
        crs.updated_by_user_id,
        crs.created_by_user_id,
        cr.sender_user_id
      ),
      left(
        format(
          'slot_title=%s; duration_ms=%s; recording_id=%s; artwork_preview_path=%s',
          crs.title,
          cr.duration_ms,
          cr.id,
          coalesce(crs.artwork_preview_path, '')
        ),
        2000
      )
    from public.couple_recording_slots as crs
    join public.couple_recordings as cr
      on cr.id = crs.recording_id
    where crs.id = target_uuid
      and crs.couple_id = requested_couple_id
      and coalesce(
        crs.updated_by_user_id,
        crs.created_by_user_id,
        cr.sender_user_id
      ) = requested_partner_user_id;

    if found then
      return;
    end if;

    return query
    select
      cr.sender_user_id,
      left(
        format(
          'duration_ms=%s; storage_path=%s',
          cr.duration_ms,
          cr.storage_path
        ),
        2000
      )
    from public.couple_recordings as cr
    where cr.id = target_uuid
      and cr.couple_id = requested_couple_id
      and cr.sender_user_id = requested_partner_user_id;
  elsif requested_target_type = 'calendar_event' then
    return query
    select
      cce.updated_by_user_id,
      left(concat_ws(E'\n', cce.title, cce.memo), 2000)
    from public.couple_calendar_events as cce
    where cce.id = target_uuid
      and cce.couple_id = requested_couple_id
      and cce.updated_by_user_id = requested_partner_user_id;
  elsif requested_target_type = 'character' then
    return query
    select
      cc.updated_by,
      left(
        format(
          'image_path=%s; drawing_data_path=%s',
          cc.image_path,
          cc.drawing_data_path
        ),
        2000
      )
    from public.couple_characters as cc
    where cc.couple_id = target_uuid
      and cc.couple_id = requested_couple_id
      and cc.updated_by = requested_partner_user_id;
  elsif requested_target_type = 'ai_direct_answer' then
    return query
    select
      null::uuid,
      left(
        concat_ws(
          E'\n',
          aiuq.answer_text,
          case
            when aiuqf.question_text is not null
              then 'follow_up_question=' || aiuqf.question_text
            else null
          end
        ),
        2000
      )
    from public.ai_user_questions as aiuq
    left join public.ai_user_question_follow_ups as aiuqf
      on aiuqf.user_question_id = aiuq.id
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
