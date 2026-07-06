do $$
begin
  if exists (
    select 1
    from public.daily_questions
    where story_loop_id is null
  ) then
    raise exception 'daily_question_story_loop_not_null_prerequisite_failed';
  end if;

  if exists (
    select story_loop_id
    from public.daily_questions
    group by story_loop_id
    having count(*) > 1
  ) then
    raise exception 'daily_question_story_loop_unique_prerequisite_failed';
  end if;
end;
$$;

create unique index if not exists daily_questions_story_loop_unique_idx
  on public.daily_questions (story_loop_id);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.daily_questions'::regclass
      and conname = 'daily_questions_story_loop_unique'
  ) then
    alter table public.daily_questions
      add constraint daily_questions_story_loop_unique
      unique using index daily_questions_story_loop_unique_idx;
  end if;
end;
$$;

alter table public.daily_questions
  alter column story_loop_id set not null;

drop index if exists public.daily_questions_story_loop_id_idx;
