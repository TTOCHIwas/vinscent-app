begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'character-a@example.test',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'character-b@example.test',
    now(),
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
  '20000000-0000-0000-0000-000000000001',
  'CHARTEST',
  '10000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  current_date - 30,
  'active',
  now(),
  'custom'
);

insert into public.couple_characters (
  couple_id,
  image_path,
  drawing_data_path,
  updated_by
)
values (
  '20000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001/current.png',
  '20000000-0000-0000-0000-000000000001/current.json',
  '10000000-0000-0000-0000-000000000001'
);

insert into storage.objects (bucket_id, name)
values
  (
    'couple-characters',
    '20000000-0000-0000-0000-000000000001/current.png'
  ),
  (
    'couple-characters',
    '20000000-0000-0000-0000-000000000001/current.json'
  ),
  (
    'couple-characters',
    '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/preview.png'
  ),
  (
    'couple-characters',
    '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/drawing.json'
  ),
  (
    'couple-characters',
    '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000003/preview.png'
  ),
  (
    'couple-characters',
    '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000003/drawing.json'
  );

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  $$
    select *
    from public.upsert_couple_character(
      '20000000-0000-0000-0000-000000000001/revisions/not-a-uuid/preview.png',
      '20000000-0000-0000-0000-000000000001/revisions/not-a-uuid/drawing.json'
    )
  $$,
  'P0001',
  'invalid_character_path',
  'finalize rejects a malformed revision path'
);

select throws_ok(
  $$
    select *
    from public.upsert_couple_character(
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/preview.png',
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000003/drawing.json'
    )
  $$,
  'P0001',
  'invalid_character_path',
  'finalize rejects artifacts from different revisions'
);

select lives_ok(
  $$
    select *
    from public.upsert_couple_character(
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/preview.png',
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/drawing.json'
    )
  $$,
  'finalize accepts a complete immutable artifact revision'
);

reset role;

select is(
  (
    select drawing_data_path
    from public.couple_characters
    where couple_id = '20000000-0000-0000-0000-000000000001'
  ),
  '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/drawing.json',
  'finalize switches both current artifact pointers together'
);

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where cleanup_reason = 'orphan_character'
      and object_path in (
        '20000000-0000-0000-0000-000000000001/current.png',
        '20000000-0000-0000-0000-000000000001/current.json'
      )
  ),
  2::bigint,
  'finalize queues both previous artifacts for cleanup'
);

set local role authenticated;

select lives_ok(
  $$
    select *
    from public.upsert_couple_character(
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/preview.png',
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/drawing.json'
    )
  $$,
  'finalize is idempotent for a retried request'
);

reset role;

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where cleanup_reason = 'orphan_character'
  ),
  2::bigint,
  'an idempotent retry does not enqueue current artifacts'
);

set local role authenticated;

select throws_ok(
  $$
    select *
    from public.upsert_couple_character(
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000002/preview.png',
      '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000002/drawing.json'
    )
  $$,
  'P0001',
  'character_artifact_missing',
  'finalize rejects a revision whose artifacts are missing'
);

reset role;

select is(
  (
    select image_path
    from public.couple_characters
    where couple_id = '20000000-0000-0000-0000-000000000001'
  ),
  '20000000-0000-0000-0000-000000000001/revisions/30000000-0000-0000-0000-000000000001/preview.png',
  'a failed finalize preserves the current preview pointer'
);

set local role authenticated;

select lives_ok(
  $$
    select public.discard_uploaded_couple_character(
      '30000000-0000-0000-0000-000000000003'
    )
  $$,
  'an unused uploaded revision can be discarded'
);

reset role;

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where cleanup_reason = 'orphan_character'
      and object_path like '%30000000-0000-0000-0000-000000000003%'
  ),
  2::bigint,
  'discard queues both unused revision artifacts'
);

set local role authenticated;

select lives_ok(
  $$
    select public.discard_uploaded_couple_character(
      '30000000-0000-0000-0000-000000000001'
    )
  $$,
  'discard ignores the currently referenced revision'
);

reset role;

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where cleanup_reason = 'orphan_character'
      and object_path like '%30000000-0000-0000-0000-000000000001%'
  ),
  0::bigint,
  'discard never queues currently referenced artifacts'
);

select is(
  (
    select character_setup_status
    from public.couples
    where id = '20000000-0000-0000-0000-000000000001'
  ),
  'custom',
  'finalize preserves the completed character setup state'
);

select * from finish();
rollback;
