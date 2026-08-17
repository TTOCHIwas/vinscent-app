create or replace function public.get_ai_question_feedback_status(
  requested_daily_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_couple_id uuid;
  published_feedback jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_daily_question_id is null then
    perform private.raise_app_error('invalid_daily_question');
  end if;

  select dq.couple_id
  into target_couple_id
  from public.daily_questions as dq
  where dq.id = requested_daily_question_id
    and dq.status = 'completed'
    and private.is_readable_couple_member(
      dq.couple_id,
      current_user_id
    );

  if target_couple_id is null then
    perform private.raise_app_error('invalid_daily_question');
  end if;

  select jsonb_build_object(
    'daily_question_id', aiqf.daily_question_id,
    'feedback_text', aiqf.feedback_text,
    'published_at', aiqf.published_at
  )
  into published_feedback
  from public.ai_question_feedbacks as aiqf
  where aiqf.daily_question_id = requested_daily_question_id
    and aiqf.couple_id = target_couple_id
    and aiqf.state = 'published'
    and aiqf.safety_status = 'passed';

  if published_feedback is not null then
    return jsonb_build_object(
      'status', 'published',
      'feedback', published_feedback
    );
  end if;

  if exists (
    select 1
    from public.ai_processing_jobs as aipj
    where aipj.daily_question_id = requested_daily_question_id
      and aipj.couple_id = target_couple_id
      and aipj.job_type = 'generate_feedback'
      and aipj.status in ('pending', 'processing')
  ) then
    return jsonb_build_object(
      'status', 'processing',
      'feedback', null
    );
  end if;

  return jsonb_build_object(
    'status', 'failed',
    'feedback', null
  );
end;
$$;

revoke execute on function public.get_ai_question_feedback_status(uuid)
  from public, anon;

grant execute on function public.get_ai_question_feedback_status(uuid)
  to authenticated;
