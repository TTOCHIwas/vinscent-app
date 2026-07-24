begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
set local timezone = 'UTC';

select plan(27);

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
    'ai-proactive-user-a@example.test',
    now(),
    now()
  ),
  (
    '18000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-proactive-user-b@example.test',
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
  character_setup_status,
  timezone
)
values (
  '28000000-0000-0000-0000-000000000001',
  'AIPROACT',
  '18000000-0000-0000-0000-000000000001',
  '18000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default',
  'UTC'
);

insert into public.ai_user_consents (
  couple_id,
  user_id,
  status,
  policy_version,
  granted_at,
  revoked_at
)
values
  (
    '28000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '28000000-0000-0000-0000-000000000001',
    '18000000-0000-0000-0000-000000000002',
    'granted',
    'ai-learning-v1',
    now(),
    null
  );

insert into public.ai_personalization_states (
  couple_id,
  curriculum_version,
  activated_at
)
select
  '28000000-0000-0000-0000-000000000001',
  aiqc.version,
  now()
from public.ai_question_curricula as aiqc
where aiqc.status = 'active'
order by aiqc.version desc
limit 1;

select ok(
  to_regclass('private.ai_proactive_suggestion_daily_usage') is not null,
  'proactive daily usage has private storage'
);
select ok(
  to_regprocedure(
    'public.claim_ai_proactive_suggestion_generation(uuid,date)'
  ) is not null,
  'proactive generation claim RPC exists'
);
select ok(
  to_regprocedure(
    'public.claim_my_ai_proactive_suggestion_impression(date,text)'
  ) is not null,
  'proactive impression claim RPC exists'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'private.ai_proactive_suggestion_daily_usage',
    'SELECT'
  ),
  'clients cannot read proactive daily usage'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_ai_proactive_suggestion_generation(uuid,date)',
    'EXECUTE'
  ),
  'clients cannot claim model generation slots'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.claim_ai_proactive_suggestion_generation(uuid,date)',
    'EXECUTE'
  ),
  'the service role can claim model generation slots'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.claim_my_ai_proactive_suggestion_impression(date,text)',
    'EXECUTE'
  ),
  'clients can claim their own impressions'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.claim_my_ai_proactive_suggestion_impression(date,text)',
    'EXECUTE'
  ),
  'anonymous clients cannot claim impressions'
);

set local role service_role;

select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000001',
    current_date
  ),
  true,
  'the first generation is allowed'
);
select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000001',
    current_date
  ),
  true,
  'the second generation is allowed'
);
select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000001',
    current_date
  ),
  true,
  'the third generation is allowed'
);
select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000001',
    current_date
  ),
  true,
  'the fourth generation is allowed'
);
select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000001',
    current_date
  ),
  true,
  'the fifth generation is allowed'
);
select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000001',
    current_date
  ),
  true,
  'the sixth generation is allowed'
);
select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000001',
    current_date
  ),
  false,
  'generation is rejected after the retry allowance'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '18000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-1'
  ),
  true,
  'the first foreground session is allowed'
);
select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-1'
  ),
  true,
  'the same foreground session is idempotent'
);
select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-2'
  ),
  true,
  'the second foreground session is allowed'
);
select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-3'
  ),
  true,
  'the third foreground session is allowed'
);
select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-4'
  ),
  false,
  'the fourth foreground session is rejected across devices'
);
select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date - 1,
    'stale-session'
  ),
  false,
  'a stale context date cannot consume an impression'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '18000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-1'
  ),
  true,
  'the partner has an independent personal allowance'
);
select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-2'
  ),
  true,
  'the partner can use a second foreground session'
);
select is(
  public.claim_my_ai_proactive_suggestion_impression(
    current_date,
    'session-3'
  ),
  true,
  'the partner can use a third foreground session'
);

reset role;
set local role service_role;

select is(
  public.claim_ai_proactive_suggestion_generation(
    '18000000-0000-0000-0000-000000000002',
    current_date
  ),
  false,
  'generation stops after three impressions'
);

reset role;

select is(
  (
    select usage.generation_count
    from private.ai_proactive_suggestion_daily_usage as usage
    where usage.user_id =
      '18000000-0000-0000-0000-000000000001'
      and usage.context_date = current_date
  ),
  6::smallint,
  'rejected generation calls do not increment the stored count'
);
select is(
  (
    select cardinality(usage.shown_session_ids)
    from private.ai_proactive_suggestion_daily_usage as usage
    where usage.user_id =
      '18000000-0000-0000-0000-000000000001'
      and usage.context_date = current_date
  ),
  3,
  'only three distinct foreground sessions are stored'
);

select * from finish();
rollback;
