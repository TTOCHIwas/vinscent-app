create or replace function private.get_story_loop_detail_row(
  target_couple_id uuid,
  target_couple_date date,
  requested_user_id uuid,
  requested_access_mode text,
  requested_current_couple_date date
)
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  loop_id uuid,
  loop_status text,
  story_edit_locked boolean,
  can_edit_story boolean,
  can_answer_question boolean,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_scene_data_path text,
  first_card_has_photo boolean,
  first_card_has_drawing boolean,
  first_card_has_text boolean,
  first_card_submitted_at timestamptz,
  first_card_revision integer,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_scene_data_path text,
  second_card_has_photo boolean,
  second_card_has_drawing boolean,
  second_card_has_text boolean,
  second_card_submitted_at timestamptz,
  second_card_revision integer,
  daily_question_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  question_status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  partner_answer_id uuid,
  partner_answer_text text,
  partner_answer_answered_at timestamptz,
  partner_answer_updated_at timestamptz,
  answer_count integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with target_loop as (
    select
      dsl.id,
      dsl.status,
      dsl.story_edit_locked_at
    from public.daily_story_loops as dsl
    where dsl.couple_id = target_couple_id
      and dsl.couple_date = target_couple_date
    limit 1
  ),
  ordered_cards as (
    select
      slc.id,
      slc.author_user_id,
      slc.preview_path,
      slc.scene_data_path,
      slc.has_photo,
      slc.has_drawing,
      slc.has_text,
      slc.submitted_at,
      slc.revision,
      row_number() over (
        order by slc.submitted_at asc, slc.id asc
      ) as card_position
    from public.story_loop_cards as slc
    where slc.couple_id = target_couple_id
      and slc.couple_date = target_couple_date
  ),
  card_count_state as (
    select
      count(*)::integer as card_count
    from ordered_cards as oc
  ),
  first_card as (
    select
      oc.id,
      oc.author_user_id,
      oc.preview_path,
      oc.scene_data_path,
      oc.has_photo,
      oc.has_drawing,
      oc.has_text,
      oc.submitted_at,
      oc.revision
    from ordered_cards as oc
    where oc.card_position = 1
  ),
  second_card as (
    select
      oc.id,
      oc.author_user_id,
      oc.preview_path,
      oc.scene_data_path,
      oc.has_photo,
      oc.has_drawing,
      oc.has_text,
      oc.submitted_at,
      oc.revision
    from ordered_cards as oc
    where oc.card_position = 2
  ),
  target_question as (
    select
      dq.id as daily_question_id,
      dq.question_id,
      dq.status as question_status,
      q.question_text,
      q.source as question_source,
      q.category as question_category,
      q.mood as question_mood
    from public.daily_questions as dq
    join public.questions as q
      on q.id = dq.question_id
    where dq.couple_id = target_couple_id
      and dq.assigned_date = target_couple_date
    limit 1
  )
  select
    target_couple_id,
    target_couple_date,
    requested_access_mode,
    tl.id,
    tl.status,
    coalesce(
      tl.story_edit_locked_at is not null,
      false
    ) or tq.daily_question_id is not null,
    requested_access_mode = 'active'
      and target_couple_date = requested_current_couple_date
      and not (
        coalesce(
          tl.story_edit_locked_at is not null,
          false
        ) or tq.daily_question_id is not null
      ),
    requested_access_mode = 'active'
      and target_couple_date = requested_current_couple_date
      and tq.daily_question_id is not null,
    coalesce(ccs.card_count, 0),
    fc.id,
    fc.author_user_id,
    fc.preview_path,
    fc.scene_data_path,
    fc.has_photo,
    fc.has_drawing,
    fc.has_text,
    fc.submitted_at,
    fc.revision,
    sc.id,
    sc.author_user_id,
    sc.preview_path,
    sc.scene_data_path,
    sc.has_photo,
    sc.has_drawing,
    sc.has_text,
    sc.submitted_at,
    sc.revision,
    tq.daily_question_id,
    tq.question_id,
    tq.question_text,
    tq.question_source,
    tq.question_category,
    tq.question_mood,
    coalesce(qas.status, tq.question_status),
    qas.my_answer_id,
    qas.my_answer_text,
    qas.my_answer_answered_at,
    qas.my_answer_updated_at,
    coalesce(qas.partner_answer_exists, false),
    qas.partner_answer_id,
    qas.partner_answer_text,
    qas.partner_answer_answered_at,
    qas.partner_answer_updated_at,
    coalesce(qas.answer_count, 0)
  from (select 1 as anchor) as base
  left join target_loop as tl
    on true
  left join card_count_state as ccs
    on true
  left join first_card as fc
    on true
  left join second_card as sc
    on true
  left join target_question as tq
    on true
  left join lateral private.get_today_question_answer_state(
    tq.daily_question_id,
    requested_user_id
  ) as qas
    on tq.daily_question_id is not null;
$$;

create or replace function public.get_today_story_loop_summary()
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  loop_id uuid,
  loop_status text,
  story_edit_locked boolean,
  can_edit_story boolean,
  can_answer_question boolean,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_submitted_at timestamptz,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_submitted_at timestamptz,
  daily_question_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  question_status text,
  my_answer_exists boolean,
  partner_answer_exists boolean,
  answer_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
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

  if current_couple_context.current_couple_date
    < current_couple_context.relationship_start_date
  then
    return;
  end if;

  return query
    select
      detail.couple_id,
      detail.couple_date,
      detail.access_mode,
      detail.loop_id,
      detail.loop_status,
      detail.story_edit_locked,
      detail.can_edit_story,
      detail.can_answer_question,
      detail.card_count,
      detail.first_card_id,
      detail.first_card_author_user_id,
      detail.first_card_preview_path,
      detail.first_card_submitted_at,
      detail.second_card_id,
      detail.second_card_author_user_id,
      detail.second_card_preview_path,
      detail.second_card_submitted_at,
      detail.daily_question_id,
      detail.question_id,
      detail.question_text,
      detail.question_source,
      detail.question_category,
      detail.question_mood,
      detail.question_status,
      detail.my_answer_id is not null,
      detail.partner_answer_exists,
      detail.answer_count
    from private.get_story_loop_detail_row(
      current_couple_context.id,
      current_couple_context.current_couple_date,
      current_user_id,
      current_couple_context.access_mode,
      current_couple_context.current_couple_date
    ) as detail;
end;
$$;

create or replace function public.get_story_loop_detail(
  target_date date
)
returns table (
  couple_id uuid,
  couple_date date,
  access_mode text,
  loop_id uuid,
  loop_status text,
  story_edit_locked boolean,
  can_edit_story boolean,
  can_answer_question boolean,
  card_count integer,
  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_scene_data_path text,
  first_card_has_photo boolean,
  first_card_has_drawing boolean,
  first_card_has_text boolean,
  first_card_submitted_at timestamptz,
  first_card_revision integer,
  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_scene_data_path text,
  second_card_has_photo boolean,
  second_card_has_drawing boolean,
  second_card_has_text boolean,
  second_card_submitted_at timestamptz,
  second_card_revision integer,
  daily_question_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  question_status text,
  my_answer_id uuid,
  my_answer_text text,
  my_answer_answered_at timestamptz,
  my_answer_updated_at timestamptz,
  partner_answer_exists boolean,
  partner_answer_id uuid,
  partner_answer_text text,
  partner_answer_answered_at timestamptz,
  partner_answer_updated_at timestamptz,
  answer_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
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

  if target_date is null
    or target_date < current_couple_context.relationship_start_date
    or target_date > current_couple_context.current_couple_date
  then
    return;
  end if;

  return query
    select *
    from private.get_story_loop_detail_row(
      current_couple_context.id,
      target_date,
      current_user_id,
      current_couple_context.access_mode,
      current_couple_context.current_couple_date
    );
end;
$$;

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
  )::date then
    return;
  end if;

  if month_end < current_couple_context.relationship_start_date then
    return;
  end if;

  return query
    with ordered_cards as (
      select
        slc.couple_date,
        dsl.status as loop_status,
        slc.id,
        slc.author_user_id,
        slc.preview_path,
        slc.submitted_at,
        row_number() over (
          partition by slc.couple_date
          order by slc.submitted_at asc, slc.id asc
        ) as card_position,
        count(*) over (
          partition by slc.couple_date
        )::integer as day_card_count
      from public.story_loop_cards as slc
      join public.daily_story_loops as dsl
        on dsl.id = slc.story_loop_id
      where slc.couple_id = current_couple_context.id
        and slc.couple_date between greatest(
          month_start,
          current_couple_context.relationship_start_date
        ) and least(
          month_end,
          current_couple_context.current_couple_date
        )
    )
    ,
    day_states as (
      select distinct
        oc.couple_date,
        oc.loop_status,
        oc.day_card_count
      from ordered_cards as oc
    ),
    first_cards as (
      select
        oc.couple_date,
        oc.id,
        oc.author_user_id,
        oc.preview_path,
        oc.submitted_at
      from ordered_cards as oc
      where oc.card_position = 1
    ),
    second_cards as (
      select
        oc.couple_date,
        oc.id,
        oc.author_user_id,
        oc.preview_path,
        oc.submitted_at
      from ordered_cards as oc
      where oc.card_position = 2
    )
    select
      ds.couple_date,
      ds.loop_status,
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
    left join first_cards as fc
      on fc.couple_date = ds.couple_date
    left join second_cards as sc
      on sc.couple_date = ds.couple_date
    order by ds.couple_date asc;
end;
$$;

revoke execute on function private.get_story_loop_detail_row(
  uuid,
  date,
  uuid,
  text,
  date
) from public, anon, authenticated;

revoke execute on function public.get_today_story_loop_summary()
  from public, anon;
revoke execute on function public.get_story_loop_detail(date)
  from public, anon;
revoke execute on function public.get_story_loop_month_summary(date)
  from public, anon;

grant execute on function public.get_today_story_loop_summary()
  to authenticated;
grant execute on function public.get_story_loop_detail(date)
  to authenticated;
grant execute on function public.get_story_loop_month_summary(date)
  to authenticated;
