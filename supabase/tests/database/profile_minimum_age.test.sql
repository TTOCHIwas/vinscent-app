begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

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
    'underage-profile@example.test',
    now(),
    now()
  ),
  (
    '19000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'boundary-profile@example.test',
    now(),
    now()
  ),
  (
    '19000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'adult-profile@example.test',
    now(),
    now()
  );

select ok(
  to_regprocedure('private.enforce_profile_minimum_age()') is not null,
  'the profile minimum-age trigger function exists'
);
select ok(
  exists(
    select 1
    from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'profiles_enforce_minimum_age'
      and not tgisinternal
  ),
  'profiles enforce minimum age on writes'
);

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  $$
    insert into public.profiles (
      id,
      display_name,
      birth_date
    )
    values (
      '19000000-0000-0000-0000-000000000001',
      'Minor',
      (
        private.current_app_date() - interval '13 years'
      )::date
    )
  $$,
  'P0001',
  'minimum_age_required',
  'an underage profile cannot be inserted directly'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select lives_ok(
  $$
    insert into public.profiles (
      id,
      display_name,
      birth_date
    )
    values (
      '19000000-0000-0000-0000-000000000002',
      'Boundary',
      (
        private.current_app_date() - interval '14 years'
      )::date
    )
  $$,
  'a profile can be created on the fourteenth birthday'
);
select is(
  (
    select count(*)
    from public.profiles
    where id = '19000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'the eligible boundary profile is stored'
);
select throws_ok(
  $$
    update public.profiles
    set birth_date = (
      private.current_app_date() - interval '13 years'
    )::date
    where id = '19000000-0000-0000-0000-000000000002'
  $$,
  'P0001',
  'minimum_age_required',
  'an existing profile cannot be changed to an underage birthday'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select lives_ok(
  $$
    insert into public.profiles (
      id,
      display_name,
      birth_date
    )
    values (
      '19000000-0000-0000-0000-000000000003',
      'Adult',
      date '2000-01-01'
    )
  $$,
  'an older eligible profile keeps the existing write path'
);

reset role;
select * from finish();
rollback;
