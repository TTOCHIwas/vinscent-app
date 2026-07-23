begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

select ok(
  to_regclass('public.ai_feature_entitlements') is not null,
  'ai_feature_entitlements exists'
);
select ok(
  to_regprocedure(
    'private.has_ai_feature_entitlement(uuid,text)'
  ) is not null,
  'AI feature entitlement helper exists'
);
select ok(
  (
    select relrowsecurity
    from pg_class
    where oid = 'public.ai_feature_entitlements'::regclass
  ),
  'AI feature entitlements use row level security'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.ai_feature_entitlements',
    'SELECT'
  ),
  'clients cannot read entitlement storage directly'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.ai_feature_entitlements',
    'INSERT'
  ),
  'clients cannot grant entitlements'
);

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
    '11000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-feature-user-a@example.test',
    now(),
    now()
  ),
  (
    '11000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-feature-user-b@example.test',
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
  '21000000-0000-0000-0000-000000000001',
  'AIFEAT01',
  '11000000-0000-0000-0000-000000000001',
  '11000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default'
);

insert into public.ai_feature_entitlements (
  couple_id,
  feature_key,
  source,
  is_enabled,
  expires_at
)
values
  (
    '21000000-0000-0000-0000-000000000001',
    'focused_questions',
    'development',
    true,
    null
  ),
  (
    '21000000-0000-0000-0000-000000000001',
    'monthly_report',
    'development',
    false,
    null
  ),
  (
    '21000000-0000-0000-0000-000000000001',
    'expired_feature',
    'development',
    true,
    now() - interval '1 minute'
  );

select set_config(
  'request.jwt.claim.sub',
  '11000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_ai_learning_dashboard()->'enabled_features',
  '["focused_questions"]'::jsonb,
  'dashboard exposes only enabled and unexpired features'
);

reset role;

select is(
  private.has_ai_feature_entitlement(
    '21000000-0000-0000-0000-000000000001',
    'focused_questions'
  ),
  true,
  'server feature checks use the same entitlement state'
);

select * from finish();
rollback;
