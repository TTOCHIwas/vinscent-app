create or replace function private.ai_direct_question_daily_limit()
returns smallint
language sql
immutable
parallel safe
set search_path = ''
as $$
  select 3::smallint;
$$;

update public.ai_user_question_daily_usage
set submission_count = least(submission_count, 3)
where submission_count > 3;

alter table public.ai_user_question_daily_usage
  drop constraint if exists ai_user_question_daily_usage_count_check;

alter table public.ai_user_question_daily_usage
  add constraint ai_user_question_daily_usage_count_check
    check (submission_count between 0 and 3);

revoke execute on function private.ai_direct_question_daily_limit()
  from public, anon, authenticated;
