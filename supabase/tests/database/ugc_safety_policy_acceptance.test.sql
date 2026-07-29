begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(16);

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
    '18000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ugc-policy-user-a@example.test',
    now(),
    now()
  ),
  (
    '18000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ugc-policy-user-b@example.test',
    now(),
    now()
  );

select ok(
  to_regclass('public.user_policy_acceptances') is not null,
  'user policy acceptances exist'
);
select ok(
  to_regprocedure('public.get_my_ugc_safety_policy_status()') is not null,
  'current UGC safety policy status RPC exists'
);
select ok(
  to_regprocedure(
    'public.accept_current_ugc_safety_policy(text)'
  ) is not null,
  'UGC safety policy acceptance RPC exists'
);
select ok(
  to_regprocedure(
    'private.has_current_ugc_safety_policy_acceptance(uuid)'
  ) is not null,
  'server-side current acceptance helper exists'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.get_my_ugc_safety_policy_status()',
    'EXECUTE'
  ),
  'anonymous users cannot inspect acceptance status'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.accept_current_ugc_safety_policy(text)',
    'EXECUTE'
  ),
  'anonymous users cannot accept the policy'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.user_policy_acceptances',
    'INSERT'
  ),
  'authenticated users cannot forge acceptance rows directly'
);
select is(
  private.has_current_ugc_safety_policy_acceptance(
    '18000000-0000-0000-0000-000000000001'
  ),
  false,
  'a user starts without current policy acceptance'
);

select set_config(
  'request.jwt.claim.sub',
  '18000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select results_eq(
  $$
    select policy_version, is_accepted
    from public.get_my_ugc_safety_policy_status()
  $$,
  $$
    values ('ugc-safety-v1'::text, false)
  $$,
  'status exposes the current version before acceptance'
);
select throws_ok(
  $$
    select *
    from public.accept_current_ugc_safety_policy('ugc-safety-old')
  $$,
  'P0001',
  'ugc_safety_policy_version_outdated',
  'a stale client cannot accept an outdated version'
);
select throws_ok(
  $$
    select *
    from public.accept_current_ugc_safety_policy(null)
  $$,
  'P0001',
  'ugc_safety_policy_version_outdated',
  'a missing policy version cannot create acceptance'
);
select results_eq(
  $$
    select policy_version, is_accepted
    from public.accept_current_ugc_safety_policy('ugc-safety-v1')
  $$,
  $$
    values ('ugc-safety-v1'::text, true)
  $$,
  'the current policy can be accepted'
);

reset role;

create temporary table captured_policy_acceptance as
select accepted_at
from public.user_policy_acceptances
where user_id = '18000000-0000-0000-0000-000000000001'
  and policy_type = 'ugc_safety_policy'
  and policy_version = 'ugc-safety-v1';

select is(
  (
    select count(*)
    from public.user_policy_acceptances
    where user_id = '18000000-0000-0000-0000-000000000001'
      and policy_type = 'ugc_safety_policy'
      and policy_version = 'ugc-safety-v1'
  ),
  1::bigint,
  'acceptance creates one auditable versioned row'
);
select is(
  private.has_current_ugc_safety_policy_acceptance(
    '18000000-0000-0000-0000-000000000001'
  ),
  true,
  'the server helper recognizes current acceptance'
);

set local role authenticated;

select results_eq(
  $$
    select accepted_at
    from public.accept_current_ugc_safety_policy('ugc-safety-v1')
  $$,
  $$
    select accepted_at
    from captured_policy_acceptance
  $$,
  'repeated acceptance preserves the original audit time'
);

reset role;

delete from auth.users
where id = '18000000-0000-0000-0000-000000000001';

select is(
  (
    select count(*)
    from public.user_policy_acceptances
    where user_id = '18000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'account deletion removes the acceptance audit row'
);

select * from finish();
rollback;
