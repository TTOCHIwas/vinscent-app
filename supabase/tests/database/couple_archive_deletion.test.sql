begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(4);

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
