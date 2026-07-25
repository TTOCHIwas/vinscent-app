alter table public.app_notification_events
  drop constraint if exists app_notification_events_type_check;

alter table public.app_notification_events
  add constraint app_notification_events_type_check
  check (
    event_type in (
      'couple_setup_started',
      'couple_setup_completed',
      'couple_character_updated',
      'couple_reconnected',
      'ai_feedback_ready',
      'ai_memory_review_ready',
      'ai_personalization_activated',
      'ai_direct_answer_ready',
      'ai_direct_answer_failed',
      'ai_focused_partner_waiting'
    )
  );

create or replace function private.notify_ai_user_question_result()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  target_event_type text;
begin
  if new.status not in ('completed', 'failed') then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.status = new.status then
      return new;
    end if;
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.id = new.couple_id
    and c.status = 'active'
    and c.user_b_id is not null
    and new.requester_user_id in (c.user_a_id, c.user_b_id);

  if not found then
    return new;
  end if;

  target_event_type := case new.status
    when 'completed' then 'ai_direct_answer_ready'
    else 'ai_direct_answer_failed'
  end;

  perform private.emit_app_notification_event(
    new.couple_id,
    null,
    new.requester_user_id,
    target_event_type,
    null,
    null,
    jsonb_build_object(
      'user_question_id',
      new.id,
      'result_status',
      new.status
    ),
    'ai_user_question_result:' || new.id::text || ':' || new.status
  );

  return new;
end;
$$;

create trigger ai_user_questions_notify_result
  after insert or update of status on public.ai_user_questions
  for each row
  execute function private.notify_ai_user_question_result();

create or replace function private.emit_ai_focused_partner_waiting_notification(
  target_couple_id uuid,
  completing_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  partner_user_id uuid;
  completing_user_answered_count integer;
  partner_answered_count integer;
begin
  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_couple_id
    and c.status = 'active'
    and c.user_b_id is not null
    and completing_user_id in (c.user_a_id, c.user_b_id);

  if not found
    or not private.have_all_couple_members_granted_ai_consent(
      target_couple_id
    )
    or not private.has_ai_feature_entitlement(
      target_couple_id,
      'focused_questions'
    )
  then
    return;
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    return;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_focused_partner_waiting'),
    hashtext(
      target_couple_id::text || ':' || active_curriculum.version::text
    )
  );

  partner_user_id := case
    when target_couple.user_a_id = completing_user_id
      then target_couple.user_b_id
    else target_couple.user_a_id
  end;

  select count(*)::integer
  into completing_user_answered_count
  from public.questions as q
  where q.curriculum_version = active_curriculum.version
    and q.is_active
    and private.has_ai_foundation_answer(
      target_couple_id,
      q.id,
      completing_user_id
    );

  if completing_user_answered_count < active_curriculum.question_count then
    return;
  end if;

  select count(*)::integer
  into partner_answered_count
  from public.questions as q
  where q.curriculum_version = active_curriculum.version
    and q.is_active
    and private.has_ai_foundation_answer(
      target_couple_id,
      q.id,
      partner_user_id
    );

  if partner_answered_count >= active_curriculum.question_count then
    return;
  end if;

  perform private.emit_app_notification_event(
    target_couple_id,
    completing_user_id,
    partner_user_id,
    'ai_focused_partner_waiting',
    null,
    active_curriculum.version,
    jsonb_build_object(
      'completed_count',
      completing_user_answered_count,
      'total_count',
      active_curriculum.question_count
    ),
    'ai_focused_partner_waiting:' || target_couple_id::text || ':'
      || active_curriculum.version::text || ':'
      || completing_user_id::text || ':' || partner_user_id::text
  );
end;
$$;

create or replace function private.notify_ai_focused_partner_from_focused_answer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple_id uuid;
begin
  select aifq.couple_id
  into target_couple_id
  from public.ai_focused_questions as aifq
  where aifq.id = new.focused_question_id;

  if target_couple_id is not null then
    perform private.emit_ai_focused_partner_waiting_notification(
      target_couple_id,
      new.user_id
    );
  end if;

  return new;
end;
$$;

create trigger ai_focused_answers_notify_partner_waiting
  after insert on public.ai_focused_question_answers
  for each row
  execute function private.notify_ai_focused_partner_from_focused_answer();

create or replace function private.notify_ai_focused_partner_from_daily_answer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple_id uuid;
begin
  select dq.couple_id
  into target_couple_id
  from public.daily_questions as dq
  where dq.id = new.daily_question_id;

  if target_couple_id is not null then
    perform private.emit_ai_focused_partner_waiting_notification(
      target_couple_id,
      new.user_id
    );
  end if;

  return new;
end;
$$;

create trigger daily_question_answers_notify_focused_partner_waiting
  after insert on public.daily_question_answers
  for each row
  execute function private.notify_ai_focused_partner_from_daily_answer();

revoke execute on function private.notify_ai_user_question_result()
  from public, anon, authenticated;
revoke execute on function
  private.emit_ai_focused_partner_waiting_notification(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function
  private.notify_ai_focused_partner_from_focused_answer()
  from public, anon, authenticated;
revoke execute on function
  private.notify_ai_focused_partner_from_daily_answer()
  from public, anon, authenticated;
