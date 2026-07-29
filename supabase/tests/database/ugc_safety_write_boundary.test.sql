begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

insert into auth.users (
  id,
  aud,
  role,
  email,
  created_at,
  updated_at
)
values
  (
    '19000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ugc-write-user-a@example.test',
    now(),
    now()
  ),
  (
    '19000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ugc-write-user-b@example.test',
    now(),
    now()
  ),
  (
    '19000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'ugc-connect-user-a@example.test',
    now(),
    now()
  ),
  (
    '19000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'ugc-connect-user-b@example.test',
    now(),
    now()
  );

insert into public.profiles (
  id,
  display_name,
  birth_date,
  onboarding_completed_at
)
values
  (
    '19000000-0000-0000-0000-000000000003',
    'User C',
    date '2000-01-01',
    now()
  ),
  (
    '19000000-0000-0000-0000-000000000004',
    'User D',
    date '2000-01-01',
    now()
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  status,
  connected_at,
  character_setup_status
)
values (
  '29000000-0000-0000-0000-000000000001',
  'UGCW01',
  '19000000-0000-0000-0000-000000000001',
  '19000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default'
);

insert into public.couple_recordings (
  id,
  couple_id,
  sender_user_id,
  storage_path,
  duration_ms
)
values (
  '49000000-0000-0000-0000-000000000001',
  '29000000-0000-0000-0000-000000000001',
  '19000000-0000-0000-0000-000000000001',
  '29000000-0000-0000-0000-000000000001/recordings/'
    || '49000000-0000-0000-0000-000000000001.m4a',
  1000
);

insert into public.couple_recording_slots (
  id,
  couple_id,
  slot_index,
  title,
  recording_id,
  created_by_user_id,
  updated_by_user_id
)
values (
  '59000000-0000-0000-0000-000000000001',
  '29000000-0000-0000-0000-000000000001',
  1,
  '인사',
  '49000000-0000-0000-0000-000000000001',
  '19000000-0000-0000-0000-000000000001',
  '19000000-0000-0000-0000-000000000001'
);

insert into public.couple_recording_slot_placements (
  slot_id,
  couple_id,
  normalized_x,
  normalized_y,
  updated_by_user_id
)
values (
  '59000000-0000-0000-0000-000000000001',
  '29000000-0000-0000-0000-000000000001',
  0.5,
  0.5,
  '19000000-0000-0000-0000-000000000001'
);

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  status,
  character_setup_status
)
values (
  '29000000-0000-0000-0000-000000000002',
  'UGCW23',
  '19000000-0000-0000-0000-000000000003',
  'pending',
  'default'
);

select ok(
  to_regprocedure(
    'private.enforce_current_user_ugc_safety_policy_acceptance()'
  ) is not null,
  'the shared UGC write trigger function exists'
);
select ok(
  has_function_privilege(
    'authenticated',
    'private.has_current_user_ugc_safety_policy_acceptance()',
    'EXECUTE'
  ),
  'authenticated storage policies can evaluate current acceptance'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_trigger as trigger
    join pg_catalog.pg_class as relation
      on relation.oid = trigger.tgrelid
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where not trigger.tgisinternal
      and namespace.nspname = 'public'
      and trigger.tgname in (
        'daily_question_answers_require_ugc_policy',
        'couple_characters_require_ugc_policy',
        'couple_recordings_require_ugc_policy',
        'couple_current_recordings_require_ugc_policy',
        'couple_recording_slots_require_ugc_policy',
        'couple_recording_slot_placements_require_ugc_policy',
        'story_loop_cards_require_ugc_policy',
        'ai_focused_question_answers_require_ugc_policy',
        'ai_user_questions_require_ugc_policy',
        'couple_calendar_events_require_ugc_policy',
        'couples_require_ugc_policy_on_activation'
      )
  ),
  11::bigint,
  'shared UGC roots and couple activation enforce the current policy'
);
select is(
  (
    select count(*)
    from pg_catalog.pg_policies
    where schemaname = 'storage'
      and policyname in (
        'couple_characters_storage_insert_member',
        'couple_characters_storage_update_member',
        'couple_recordings_storage_insert_member',
        'couple_recording_artworks_storage_insert_member',
        'story_cards_storage_insert_member',
        'story_cards_storage_update_member',
        'couple_calendar_artworks_storage_insert_member'
      )
      and position(
        'has_current_user_ugc_safety_policy_acceptance'
        in coalesce(with_check, '')
      ) > 0
  ),
  7::bigint,
  'all shared UGC storage writes require current acceptance'
);

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (
    select is_accepted
    from public.get_my_ugc_safety_policy_status()
  ),
  false,
  'the current user starts without write permission'
);
select throws_ok(
  $$
    insert into storage.objects (bucket_id, name)
    values (
      'couple-recordings',
      '29000000-0000-0000-0000-000000000001/recordings/'
        || '49000000-0000-0000-0000-000000000002.m4a'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "objects"',
  'an unaccepted user cannot upload shared UGC'
);
select lives_ok(
  $$
    select public.delete_couple_recording_slot_placement(
      '59000000-0000-0000-0000-000000000001',
      1
    )
  $$,
  'policy acceptance is not required to remove a home placement'
);
select lives_ok(
  $$
    select public.delete_couple_recording_slot(
      '59000000-0000-0000-0000-000000000001',
      1
    )
  $$,
  'policy acceptance is not required to remove an existing slot'
);
select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '39000000-0000-0000-0000-000000000001',
      '함께 걷기',
      current_date,
      'none',
      null,
      null,
      false,
      false,
      0,
      '09:00:00',
      null
    )
  $$,
  'P0001',
  'ugc_safety_policy_acceptance_required',
  'an unaccepted user cannot create shared UGC'
);
select lives_ok(
  $$
    select *
    from public.accept_current_ugc_safety_policy('ugc-safety-v1')
  $$,
  'the current user can accept the current policy'
);
select is(
  (
    select is_accepted
    from public.get_my_ugc_safety_policy_status()
  ),
  true,
  'acceptance opens the current user write boundary'
);
select lives_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '39000000-0000-0000-0000-000000000001',
      '함께 걷기',
      current_date,
      'none',
      null,
      null,
      false,
      false,
      0,
      '09:00:00',
      null
    )
  $$,
  'an accepted user can create shared UGC'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select throws_ok(
  $$
    select *
    from public.save_couple_calendar_event(
      '39000000-0000-0000-0000-000000000001',
      '함께 산책하기',
      current_date,
      'none',
      null,
      null,
      false,
      false,
      0,
      '09:00:00',
      1
    )
  $$,
  'P0001',
  'ugc_safety_policy_acceptance_required',
  'one member acceptance does not grant the partner write permission'
);

reset role;

select is(
  (
    select title
    from public.couple_calendar_events
    where id = '39000000-0000-0000-0000-000000000001'
  ),
  '함께 걷기',
  'a rejected partner update preserves existing UGC'
);

insert into public.user_policy_acceptances (
  user_id,
  policy_type,
  policy_version
)
values (
  '19000000-0000-0000-0000-000000000004',
  'ugc_safety_policy',
  'ugc-safety-v1'
);

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000004',
  true
);
set local role authenticated;

select throws_ok(
  $$
    select *
    from public.join_couple_by_code('UGCW23')
  $$,
  'P0001',
  'ugc_safety_policy_acceptance_required',
  'a couple cannot activate until both members accept'
);

reset role;

insert into public.user_policy_acceptances (
  user_id,
  policy_type,
  policy_version
)
values (
  '19000000-0000-0000-0000-000000000003',
  'ugc_safety_policy',
  'ugc-safety-v1'
);

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000004',
  true
);
set local role authenticated;

select lives_ok(
  $$
    select *
    from public.join_couple_by_code('UGCW23')
  $$,
  'a couple can activate after both members accept'
);

reset role;

select is(
  (
    select status
    from public.couples
    where id = '29000000-0000-0000-0000-000000000002'
  ),
  'active',
  'successful acceptance preserves the existing connection flow'
);

select * from finish();
rollback;
