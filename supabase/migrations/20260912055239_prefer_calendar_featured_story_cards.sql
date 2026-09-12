create or replace function public.get_story_loop_month_summary(
  target_month date
)
returns table (
  couple_date date,
  loop_status text,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_submitted_at timestamptz,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_submitted_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
  month_start date;
  month_end date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into current_couple_context
  from private.get_current_couple_context()
  limit 1;

  if not found then
    return;
  end if;

  if current_couple_context.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_month is null then
    return;
  end if;

  month_start := date_trunc('month', target_month::timestamp)::date;
  month_end := (month_start + interval '1 month' - interval '1 day')::date;

  if month_start > date_trunc(
    'month',
    current_couple_context.current_couple_date::timestamp
  )::date
    or month_end < current_couple_context.relationship_start_date
  then
    return;
  end if;

  return query
    with ranked_author_cards as (
      select
        slc.*,
        dsl.status as resolved_loop_status,
        row_number() over (
          partition by slc.couple_date, slc.author_user_id
          order by
            slc.is_featured desc,
            slc.submitted_at desc,
            slc.id desc
        ) as author_rank
      from public.story_loop_cards as slc
      join public.daily_story_loops as dsl on dsl.id = slc.story_loop_id
      where slc.couple_id = current_couple_context.id
        and slc.couple_date between greatest(
          month_start,
          current_couple_context.relationship_start_date
        ) and least(
          month_end,
          current_couple_context.current_couple_date
        )
    ),
    ordered_cards as (
      select
        ranked.couple_date,
        ranked.resolved_loop_status,
        ranked.id,
        ranked.author_user_id,
        ranked.preview_path,
        ranked.submitted_at,
        row_number() over (
          partition by ranked.couple_date
          order by ranked.submitted_at asc, ranked.id asc
        ) as card_position,
        count(*) over (
          partition by ranked.couple_date
        )::integer as day_card_count
      from ranked_author_cards as ranked
      where ranked.author_rank = 1
    ),
    day_states as (
      select distinct
        oc.couple_date,
        oc.resolved_loop_status,
        oc.day_card_count
      from ordered_cards as oc
    ),
    first_cards as (
      select *
      from ordered_cards
      where card_position = 1
    ),
    second_cards as (
      select *
      from ordered_cards
      where card_position = 2
    )
    select
      ds.couple_date,
      ds.resolved_loop_status,
      ds.day_card_count,
      fc.id,
      fc.author_user_id,
      fc.preview_path,
      fc.submitted_at,
      sc.id,
      sc.author_user_id,
      sc.preview_path,
      sc.submitted_at
    from day_states as ds
    left join first_cards as fc on fc.couple_date = ds.couple_date
    left join second_cards as sc on sc.couple_date = ds.couple_date
    order by ds.couple_date;
end;
$$;
