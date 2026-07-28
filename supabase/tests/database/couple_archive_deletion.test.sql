begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '10000000-0000-0000-0000-000000000011',
    'authenticated',
    'authenticated',
    'archive-a@example.test',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000012',
    'authenticated',
    'authenticated',
    'archive-b@example.test',
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
  disconnected_at,
  disconnected_by_user_id,
  archive_expires_at
)
values (
  '20000000-0000-0000-0000-000000000011',
  'ARCHTEST',
  '10000000-0000-0000-0000-000000000011',
  '10000000-0000-0000-0000-000000000012',
  current_date - 30,
  'disconnected',
  now() - interval '1 day',
  now(),
  '10000000-0000-0000-0000-000000000011',
  now() + interval '30 days'
);

insert into storage.objects (bucket_id, name)
values
  (
    'couple-recordings',
    '20000000-0000-0000-0000-000000000011/recordings/orphan.m4a'
  ),
  (
    'couple-characters',
    '20000000-0000-0000-0000-000000000011/revisions/30000000-0000-0000-0000-000000000011/preview.png'
  ),
  (
    'story-cards',
    '20000000-0000-0000-0000-000000000011/loops/2026-07-29/10000000-0000-0000-0000-000000000011/revision/preview.png'
  ),
  (
    'couple-recording-artworks',
    '20000000-0000-0000-0000-000000000011/slots/30000000-0000-0000-0000-000000000012/artworks/30000000-0000-0000-0000-000000000013/preview.webp'
  ),
  (
    'couple-calendar-artworks',
    '20000000-0000-0000-0000-000000000011/events/30000000-0000-0000-0000-000000000014/artworks/30000000-0000-0000-0000-000000000015/preview.webp'
  ),
  (
    'couple-recordings',
    '20000000-0000-0000-0000-000000000099/recordings/untouched.m4a'
  );

insert into public.questions (
  id,
  source,
  question_key,
  question_text,
  is_active,
  personalized_for_couple_id
)
values (
  '40000000-0000-0000-0000-000000000011',
  'ai',
  'archive_deletion_test_question',
  'This couple-scoped question must be deleted.',
  false,
  '20000000-0000-0000-0000-000000000011'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000011',
  true
);
set local role authenticated;

select lives_ok(
  $$ select public.delete_disconnected_couple_archive_now() $$,
  'the first member can delete the disconnected archive'
);

reset role;

select is(
  (
    select count(*)
    from public.couples
    where id = '20000000-0000-0000-0000-000000000011'
  ),
  0::bigint,
  'the archive is removed after the first request'
);

select is(
  (
    select count(*)
    from public.questions
    where id = '40000000-0000-0000-0000-000000000011'
  ),
  0::bigint,
  'couple-scoped AI question text is deleted with the archive'
);

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where object_path like
      '20000000-0000-0000-0000-000000000011/%'
  ),
  5::bigint,
  'all couple-prefixed storage objects are queued'
);

select results_eq(
  $$
    select bucket_id, cleanup_reason
    from public.storage_cleanup_requests
    where object_path like
      '20000000-0000-0000-0000-000000000011/%'
    order by bucket_id
  $$,
  $$
    values
      ('couple-calendar-artworks'::text, 'archive_calendar_artwork'::text),
      ('couple-characters'::text, 'archive_character'::text),
      ('couple-recording-artworks'::text, 'archive_recording_artwork'::text),
      ('couple-recordings'::text, 'archive_recording'::text),
      ('story-cards'::text, 'archive_story_card'::text)
  $$,
  'each storage bucket uses its supported archive cleanup reason'
);

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where object_path =
      '20000000-0000-0000-0000-000000000099/recordings/untouched.m4a'
  ),
  0::bigint,
  'storage objects from another couple prefix are not queued'
);

select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000012',
  true
);
set local role authenticated;

select lives_ok(
  $$ select public.delete_disconnected_couple_archive_now() $$,
  'the other member can safely repeat deletion after the archive is gone'
);

reset role;

select is(
  (
    select count(*)
    from public.couples
    where id = '20000000-0000-0000-0000-000000000011'
  ),
  0::bigint,
  'a repeated request keeps the archive deleted'
);

select * from finish();
rollback;
