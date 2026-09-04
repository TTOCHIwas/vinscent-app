create or replace function private.is_current_ai_question_source_run(
  target_run_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select
        air.task <> 'generate_personalized_question'
        or air.prompt_version = 'personalized-question-v11'
      from public.ai_runs as air
      where air.id = target_run_id
    ),
    false
  );
$$;

update public.ai_question_recommendations as aiqr
set status = 'expired'
where aiqr.status = 'pending'
  and aiqr.source_run_id is not null
  and not private.is_current_ai_question_source_run(aiqr.source_run_id);

update public.questions as q
set is_active = false
where q.id in (
  select aiqr.question_id
  from public.ai_question_recommendations as aiqr
  where aiqr.status = 'expired'
    and aiqr.source_run_id is not null
    and not private.is_current_ai_question_source_run(aiqr.source_run_id)
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.question_id = aiqr.question_id
    )
);

revoke execute on function private.is_current_ai_question_source_run(uuid)
  from public, anon, authenticated;
