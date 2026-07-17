create or replace function private.prevent_completed_question_answer_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.daily_questions as dq
    where dq.id = new.daily_question_id
      and dq.status = 'completed'
  ) then
    perform private.raise_app_error('question_not_ready');
  end if;

  return new;
end;
$$;

drop trigger if exists daily_question_answers_prevent_completed_write
  on public.daily_question_answers;

create trigger daily_question_answers_prevent_completed_write
  before insert or update on public.daily_question_answers
  for each row
  execute function private.prevent_completed_question_answer_write();

revoke execute on function private.prevent_completed_question_answer_write()
  from public, anon, authenticated;
