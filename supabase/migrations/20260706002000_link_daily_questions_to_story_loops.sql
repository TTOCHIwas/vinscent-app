do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.daily_story_loops'::regclass
      and conname = 'daily_story_loops_reference_unique'
  ) then
    alter table public.daily_story_loops
      add constraint daily_story_loops_reference_unique
      unique (couple_id, couple_date, id);
  end if;
end;
$$;

alter table public.daily_questions
  add column story_loop_id uuid;

alter table public.daily_questions
  add constraint daily_questions_story_loop_match_fkey
    foreign key (couple_id, assigned_date, story_loop_id)
    references public.daily_story_loops(couple_id, couple_date, id)
    on delete cascade
    not valid;

alter table public.daily_questions
  validate constraint daily_questions_story_loop_match_fkey;

create index daily_questions_story_loop_id_idx
  on public.daily_questions (story_loop_id)
  where story_loop_id is not null;
