begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(25);

select has_column(
  'public',
  'story_loop_cards',
  'card_type',
  'story cards persist their visual format'
);
select col_default_is(
  'public',
  'story_loop_cards',
  'card_type',
  'polaroid',
  'existing and legacy clients default to polaroid'
);
select has_column(
  'public',
  'story_loop_cards',
  'layout_version',
  'story cards persist the frame geometry version'
);
select col_default_is(
  'public',
  'story_loop_cards',
  'layout_version',
  '1',
  'existing and legacy clients retain the original frame geometry'
);
select has_function(
  'public',
  'upsert_today_story_loop_card_v2',
  array[
    'uuid', 'text', 'text', 'text', 'boolean', 'boolean', 'boolean',
    'integer', 'integer', 'text', 'integer', 'boolean', 'integer'
  ],
  'the format-aware write boundary exists'
);
select has_function(
  'public',
  'upsert_today_story_loop_card_v3',
  array[
    'uuid', 'text', 'text', 'text', 'boolean', 'boolean', 'boolean',
    'integer', 'integer', 'text', 'integer', 'boolean', 'integer', 'integer'
  ],
  'the layout-aware write boundary exists'
);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '81000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'format-a@example.test',
    now(),
    now()
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'format-b@example.test',
    now(),
    now()
  );

insert into public.user_policy_acceptances (
  user_id,
  policy_type,
  policy_version
)
values
  (
    '81000000-0000-0000-0000-000000000001',
    'ugc_safety_policy',
    'ugc-safety-v1'
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    'ugc_safety_policy',
    'ugc-safety-v1'
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  timezone,
  status,
  connected_at,
  character_setup_status
)
values (
  '82000000-0000-0000-0000-000000000001',
  'FORMAT1',
  '81000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000002',
  current_date - 30,
  'UTC',
  'active',
  now(),
  'default'
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '83000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  current_date,
  'waiting_partner_card'
);

insert into public.story_loop_cards (
  id,
  story_loop_id,
  couple_id,
  couple_date,
  author_user_id,
  artifact_revision,
  preview_path,
  scene_data_path,
  has_drawing
)
values (
  '84000000-0000-0000-0000-000000000001',
  '83000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001',
  current_date,
  '81000000-0000-0000-0000-000000000002',
  '85000000-0000-0000-0000-000000000001',
  '82000000-0000-0000-0000-000000000001/loops/'
    || current_date::text
    || '/81000000-0000-0000-0000-000000000002/'
    || '85000000-0000-0000-0000-000000000001/preview.png',
  '82000000-0000-0000-0000-000000000001/loops/'
    || current_date::text
    || '/81000000-0000-0000-0000-000000000002/'
    || '85000000-0000-0000-0000-000000000001/scene.json',
  true
);

select is(
  (
    select card_type
    from public.story_loop_cards
    where id = '84000000-0000-0000-0000-000000000001'
  ),
  'polaroid',
  'rows inserted without a format remain polaroids'
);
select is(
  (
    select layout_version
    from public.story_loop_cards
    where id = '84000000-0000-0000-0000-000000000001'
  ),
  1,
  'rows inserted without layout metadata retain legacy geometry'
);

insert into storage.objects (bucket_id, name)
values
  (
    'story-cards',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000004/preview.png'
  ),
  (
    'story-cards',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000004/scene.json'
  ),
  (
    'story-cards',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000004/background.jpg'
  ),
  (
    'story-cards',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000002/preview.png'
  ),
  (
    'story-cards',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000002/scene.json'
  );

select set_config(
  'request.jwt.claim.sub',
  '81000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$select * from public.upsert_today_story_loop_card_v2(
    '85000000-0000-0000-0000-000000000004',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000004/preview.png',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000004/scene.json',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000004/background.jpg',
    true,
    false,
    false,
    0,
    0,
    'full_bleed',
    1,
    false,
    null
  )$$,
  'a full-bleed photo card saves with one source photo'
);

reset role;

select is(
  (
    select card_type
    from public.story_loop_cards
    where artifact_revision = '85000000-0000-0000-0000-000000000004'
  ),
  'full_bleed',
  'the full-bleed format is persisted'
);
select is(
  (
    select layout_version
    from public.story_loop_cards
    where artifact_revision = '85000000-0000-0000-0000-000000000004'
  ),
  1,
  'legacy write clients persist legacy geometry'
);

set local role authenticated;

select throws_ok(
  $$select * from public.upsert_today_story_loop_card_v2(
    '85000000-0000-0000-0000-000000000005',
    'unused-preview',
    'unused-scene',
    'unused-background',
    true,
    false,
    false,
    0,
    0,
    'full_bleed',
    1,
    true,
    null
  )$$,
  'P0001',
  'invalid_story_card_caption',
  'full-bleed cards reject polaroid captions'
);

select lives_ok(
  $$select * from public.upsert_today_story_loop_card_v3(
    '85000000-0000-0000-0000-000000000002',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000002/preview.png',
    '82000000-0000-0000-0000-000000000001/loops/'
      || current_date::text
      || '/81000000-0000-0000-0000-000000000001/'
      || '85000000-0000-0000-0000-000000000002/scene.json',
    null,
    true,
    false,
    false,
    0,
    0,
    'four_cut_grid',
    4,
    false,
    2,
    null
  )$$,
  'a complete spacious four-cut card saves without raw background artifacts'
);

reset role;

select is(
  (
    select card_type
    from public.story_loop_cards
    where artifact_revision = '85000000-0000-0000-0000-000000000002'
  ),
  'four_cut_grid',
  'the selected four-cut format is persisted'
);
select is(
  (
    select photo_count
    from public.story_loop_cards
    where artifact_revision = '85000000-0000-0000-0000-000000000002'
  ),
  4,
  'four-cut metadata records four composed inputs'
);
select is(
  (
    select layout_version
    from public.story_loop_cards
    where artifact_revision = '85000000-0000-0000-0000-000000000002'
  ),
  2,
  'the spacious frame geometry version is persisted'
);
select is(
  (
    select background_image_path
    from public.story_loop_cards
    where artifact_revision = '85000000-0000-0000-0000-000000000002'
  ),
  null,
  'four-cut cards retain no raw source photo path'
);

update public.story_loop_cards
set submitted_at = case artifact_revision
  when '85000000-0000-0000-0000-000000000004' then now() - interval '1 minute'
  when '85000000-0000-0000-0000-000000000002' then now()
  else submitted_at
end
where artifact_revision in (
  '85000000-0000-0000-0000-000000000004',
  '85000000-0000-0000-0000-000000000002'
);

set local role authenticated;

select throws_ok(
  $$select * from public.upsert_today_story_loop_card_v3(
    '85000000-0000-0000-0000-000000000006',
    'unused-preview',
    'unused-scene',
    null,
    true,
    false,
    false,
    0,
    0,
    'four_cut_grid',
    4,
    false,
    99,
    null
  )$$,
  'P0001',
  'invalid_story_card_layout_version',
  'unknown frame geometry versions are rejected'
);

select throws_ok(
  $$select * from public.upsert_today_story_loop_card_v2(
    '85000000-0000-0000-0000-000000000003',
    'unused-preview',
    'unused-scene',
    null,
    true,
    false,
    false,
    0,
    0,
    'four_cut_strip',
    3,
    false,
    null
  )$$,
  'P0001',
  'invalid_story_card_photo_count',
  'an incomplete four-cut card is rejected at the write boundary'
);
select is(
  (
    select latest_card_type
    from public.get_today_story_card_stacks_v2()
    where author_user_id = '81000000-0000-0000-0000-000000000001'
  ),
  'four_cut_grid',
  'home stack reads expose the latest card format'
);
select is(
  (
    select count(*)::integer
    from public.get_story_card_stack_v2(
      current_date,
      '81000000-0000-0000-0000-000000000001'
    )
    where card_type = 'four_cut_grid'
  ),
  1,
  'detail stack reads expose each card format'
);
select is(
  (
    select case
      when first_card_author_user_id =
        '81000000-0000-0000-0000-000000000001'
        then first_card_type
      when second_card_author_user_id =
        '81000000-0000-0000-0000-000000000001'
        then second_card_type
    end
    from public.get_story_loop_month_summary_v2(current_date)
  ),
  'four_cut_grid',
  'calendar reads expose featured card formats'
);
select is(
  (
    select latest_layout_version
    from public.get_today_story_card_stacks_v3()
    where author_user_id = '81000000-0000-0000-0000-000000000001'
  ),
  2,
  'home stack reads expose the latest frame geometry version'
);
select is(
  (
    select layout_version
    from public.get_story_card_stack_v3(
      current_date,
      '81000000-0000-0000-0000-000000000001'
    )
    where card_type = 'four_cut_grid'
  ),
  2,
  'detail stack reads expose each frame geometry version'
);
select is(
  (
    select case
      when first_card_author_user_id =
        '81000000-0000-0000-0000-000000000001'
        then first_card_layout_version
      when second_card_author_user_id =
        '81000000-0000-0000-0000-000000000001'
        then second_card_layout_version
    end
    from public.get_story_loop_month_summary_v3(current_date)
  ),
  2,
  'calendar reads expose featured card frame geometry versions'
);

select * from finish();
rollback;
