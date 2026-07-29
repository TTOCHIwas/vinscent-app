begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
set local timezone = 'UTC';

select plan(9);

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
    '1a000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-direct-limit-user-a@example.test',
    now(),
    now()
  ),
  (
    '1a000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-direct-limit-user-b@example.test',
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
    '1a000000-0000-0000-0000-000000000001',
    'ugc_safety_policy',
    'ugc-safety-v1'
  ),
  (
    '1a000000-0000-0000-0000-000000000002',
    'ugc_safety_policy',
    'ugc-safety-v1'
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
  '2a000000-0000-0000-0000-000000000001',
  'AILIMIT1',
  '1a000000-0000-0000-0000-000000000001',
  '1a000000-0000-0000-0000-000000000002',
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
    '2a000000-0000-0000-0000-000000000001',
    '1a000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '2a000000-0000-0000-0000-000000000001',
    '1a000000-0000-0000-0000-000000000002',
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
  '2a000000-0000-0000-0000-000000000001',
  aiqc.version,
  now()
from public.ai_question_curricula as aiqc
where aiqc.status = 'active'
order by aiqc.version desc
limit 1;

select ok(
  to_regprocedure('private.ai_direct_question_daily_limit()') is not null,
  'direct questions expose one private daily-limit policy'
);
select is(
  private.ai_direct_question_daily_limit(),
  100::smallint,
  'the private policy owns the test daily limit'
);

select set_config(
  'request.jwt.claim.sub',
  '1a000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_my_ai_user_questions()->>'daily_limit',
  '100',
  'the history contract reports the test daily limit'
);
select is(
  public.get_my_ai_user_questions()->>'remaining_count',
  '100',
  'a member starts the day with the complete test allowance'
);

reset role;

select lives_ok(
  $$
    insert into public.ai_user_question_daily_usage (
      couple_id,
      user_id,
      context_date,
      submission_count
    )
    values (
      '2a000000-0000-0000-0000-000000000001',
      '1a000000-0000-0000-0000-000000000001',
      current_date,
      99
    )
  $$,
  'usage storage does not duplicate the current product limit'
);

set local role authenticated;

select is(
  public.submit_ai_user_question(
    'What helps us feel rested after a busy day?'
  )->>'remaining_count',
  '0',
  'the final allowed question consumes the shared policy limit'
);
select is(
  public.get_my_ai_user_questions()->>'remaining_count',
  '0',
  'the history contract uses the same remaining-count policy'
);
select throws_ok(
  $$
    select public.submit_ai_user_question(
      'What should we do together this weekend?'
    )
  $$,
  'P0001',
  'ai_daily_question_limit_reached',
  'a question beyond the shared limit is rejected'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.ai_user_questions
    where requester_user_id =
      '1a000000-0000-0000-0000-000000000001'
  ),
  1,
  'the rejected request does not create a question'
);

select * from finish();
rollback;
