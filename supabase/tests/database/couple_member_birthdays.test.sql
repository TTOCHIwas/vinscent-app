begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(5);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '18000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'birthday-a@example.test',
    now(),
    now()
  ),
  (
    '18000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'birthday-b@example.test',
    now(),
    now()
  ),
  (
    '18000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'birthday-outsider@example.test',
    now(),
    now()
  );

insert into public.profiles (id, display_name, birth_date)
values
  (
    '18000000-0000-0000-0000-000000000001',
    '생일A',
    '1990-07-28'
  ),
  (
    '18000000-0000-0000-0000-000000000002',
    '생일B',
    '1992-02-29'
  ),
  (
    '18000000-0000-0000-0000-000000000003',
    '외부인',
    '1994-03-01'
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  timezone,
  status,
  connected_at
)
values (
  '28000000-0000-0000-0000-000000000001',
  'BIRTHT',
  '18000000-0000-0000-0000-000000000001',
  '18000000-0000-0000-0000-000000000002',
  '2024-01-01',
  'Asia/Seoul',
  'active',
  now()
);

select has_function(
  'public',
  'get_active_couple_member_birthdays',
  array[]::text[],
  'active couple member birthdays use a narrow read boundary'
);

select set_config(
  'request.jwt.claim.sub',
  '18000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select results_eq(
  $$
    select member_role, birth_date
    from public.get_active_couple_member_birthdays()
  $$,
  $$
    values
      ('self'::text, '1990-07-28'::date),
      ('partner'::text, '1992-02-29'::date)
  $$,
  'user A sees only the two birthday values with relative roles'
);

select is(
  (select count(*) from public.profiles),
  1::bigint,
  'the existing profile policy still exposes only the current profile'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '18000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select results_eq(
  $$
    select member_role, birth_date
    from public.get_active_couple_member_birthdays()
  $$,
  $$
    values
      ('self'::text, '1992-02-29'::date),
      ('partner'::text, '1990-07-28'::date)
  $$,
  'user B receives the same dates with roles reversed'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '18000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select is_empty(
  $$
    select *
    from public.get_active_couple_member_birthdays()
  $$,
  'an outsider cannot read couple birthdays'
);

select * from finish();
rollback;
