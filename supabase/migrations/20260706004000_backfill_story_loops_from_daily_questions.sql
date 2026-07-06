insert into public.daily_story_loops (
  couple_id,
  couple_date,
  status,
  question_generated_at,
  story_edit_locked_at,
  created_at,
  updated_at
)
select
  dq.couple_id,
  dq.assigned_date,
  case dq.status
    when 'pending' then 'question_generated'
    when 'answered_by_one' then 'answered_by_one'
    when 'completed' then 'completed'
  end,
  dq.created_at,
  dq.created_at,
  dq.created_at,
  dq.updated_at
from public.daily_questions as dq
where dq.story_loop_id is null
on conflict (couple_id, couple_date) do nothing;

update public.daily_questions as dq
set story_loop_id = dsl.id
from public.daily_story_loops as dsl
where dq.story_loop_id is null
  and dsl.couple_id = dq.couple_id
  and dsl.couple_date = dq.assigned_date;

update public.daily_story_loops as dsl
set
  status = normalized.loop_status,
  question_generated_at = coalesce(
    dsl.question_generated_at,
    normalized.question_generated_at
  ),
  story_edit_locked_at = coalesce(
    dsl.story_edit_locked_at,
    normalized.story_edit_locked_at
  ),
  updated_at = greatest(
    dsl.updated_at,
    normalized.loop_updated_at
  )
from (
  select
    dq.story_loop_id,
    case dq.status
      when 'pending' then 'question_generated'
      when 'answered_by_one' then 'answered_by_one'
      when 'completed' then 'completed'
    end as loop_status,
    dq.created_at as question_generated_at,
    dq.created_at as story_edit_locked_at,
    dq.updated_at as loop_updated_at
  from public.daily_questions as dq
  where dq.story_loop_id is not null
) as normalized
where dsl.id = normalized.story_loop_id
  and not exists (
    select 1
    from public.story_loop_cards as slc
    where slc.story_loop_id = dsl.id
  )
  and (
    dsl.status is distinct from normalized.loop_status
    or dsl.question_generated_at is null
    or dsl.story_edit_locked_at is null
    or dsl.updated_at < normalized.loop_updated_at
  );

do $$
begin
  if exists (
    select 1
    from public.daily_questions
    where story_loop_id is null
  ) then
    raise exception 'daily_question_story_loop_backfill_incomplete';
  end if;

  if exists (
    select 1
    from public.daily_questions as dq
    join public.daily_story_loops as dsl
      on dsl.id = dq.story_loop_id
    where not exists (
      select 1
      from public.story_loop_cards as slc
      where slc.story_loop_id = dsl.id
    )
      and (
        dsl.status is distinct from case dq.status
          when 'pending' then 'question_generated'
          when 'answered_by_one' then 'answered_by_one'
          when 'completed' then 'completed'
        end
        or dsl.question_generated_at is null
        or dsl.story_edit_locked_at is null
        or dsl.updated_at < dq.updated_at
      )
  ) then
    raise exception 'daily_question_story_loop_status_normalization_incomplete';
  end if;
end;
$$;
