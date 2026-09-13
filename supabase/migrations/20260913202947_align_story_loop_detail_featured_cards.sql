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
      dsl.status
    from public.daily_story_loops as dsl
    where dsl.couple_id = target_couple_id
      and dsl.couple_date = target_couple_date
    limit 1
  ),
  ranked_author_cards as (
    select
      slc.*,
      row_number() over (
        partition by slc.author_user_id
        order by
          slc.is_featured desc,
          slc.submitted_at desc,
          slc.id desc
      ) as author_rank
    from public.story_loop_cards as slc
    where slc.couple_id = target_couple_id
      and slc.couple_date = target_couple_date
  ),
  ordered_cards as (
    select
      ranked.id,
      ranked.author_user_id,
      ranked.preview_path,
      ranked.scene_data_path,
      ranked.has_photo,
      ranked.has_drawing,
      ranked.has_text,
      ranked.submitted_at,
      ranked.revision,
      row_number() over (
        order by ranked.submitted_at asc, ranked.id asc
      ) as card_position
    from ranked_author_cards as ranked
    where ranked.author_rank = 1
  ),
  card_count_state as (
    select count(*)::integer as card_count
    from ordered_cards
  ),
  first_card as (
    select *
    from ordered_cards
    where card_position = 1
  ),
  second_card as (
    select *
    from ordered_cards
    where card_position = 2
  ),
  target_question as (
    select
      dq.id as daily_question_id,
      dq.question_id,
      dq.status as question_status,
      dq.closed_at as question_closed_at,
      q.question_text,
      q.source as question_source,
      q.category as question_category,
      q.mood as question_mood
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
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
    false,
    requested_access_mode = 'active'
      and target_couple_date = requested_current_couple_date,
    requested_access_mode = 'active'
      and tq.daily_question_id is not null
      and tq.question_closed_at is null
      and tq.question_status in ('pending', 'answered_by_one')
      and coalesce(qas.answer_count, 0) < 2,
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
  left join target_loop as tl on true
  left join card_count_state as ccs on true
  left join first_card as fc on true
  left join second_card as sc on true
  left join target_question as tq on true
  left join lateral private.get_today_question_answer_state(
    tq.daily_question_id,
    requested_user_id
  ) as qas on tq.daily_question_id is not null;
$$;
