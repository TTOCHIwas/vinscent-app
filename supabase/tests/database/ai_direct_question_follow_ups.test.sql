begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

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
    '17000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-follow-up-user-a@example.test',
    now(),
    now()
  ),
  (
    '17000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-follow-up-user-b@example.test',
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
  '27000000-0000-0000-0000-000000000001',
  'AIFOLLOW',
  '17000000-0000-0000-0000-000000000001',
  '17000000-0000-0000-0000-000000000002',
  current_date - 20,
  'active',
  now(),
  'default'
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
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000002',
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
  '27000000-0000-0000-0000-000000000001',
  aiqc.version,
  now()
from public.ai_question_curricula as aiqc
where aiqc.status = 'active'
order by aiqc.version desc
limit 1;

insert into public.ai_user_questions (
  id,
  couple_id,
  requester_user_id,
  question_text,
  status,
  result_kind,
  answer_text,
  answered_at
)
values
  (
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'What does my partner enjoy on a day off?',
    'completed',
    'insufficient',
    'I do not know enough yet',
    now()
  ),
  (
    '37000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'What kind of evening feels restful?',
    'completed',
    'insufficient',
    'I do not know enough yet',
    now()
  ),
  (
    '37000000-0000-0000-0000-000000000003',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'What would make a weekend fun?',
    'completed',
    'insufficient',
    'I do not know enough yet',
    now()
  ),
  (
    '37000000-0000-0000-0000-000000000004',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'What kind of walk would feel nice?',
    'completed',
    'insufficient',
    'I do not know enough yet',
    now()
  );

insert into public.ai_user_question_follow_ups (
  id,
  user_question_id,
  couple_id,
  requester_user_id,
  question_key,
  question_text,
  category,
  mood,
  rationale
)
values
  (
    '47000000-0000-0000-0000-000000000001',
    '37000000-0000-0000-0000-000000000001',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'direct_follow_up_day_off_ab12cd34',
    'What would we each enjoy doing on a day off?',
    'daily_life',
    'light',
    'There is not enough shared evidence yet'
  ),
  (
    '47000000-0000-0000-0000-000000000002',
    '37000000-0000-0000-0000-000000000002',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'direct_follow_up_evening_cd34ef56',
    'What kind of evening helps each of us unwind?',
    'daily_life',
    null,
    'There is not enough shared evidence yet'
  ),
  (
    '47000000-0000-0000-0000-000000000003',
    '37000000-0000-0000-0000-000000000003',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'direct_follow_up_evening_cd34ef56',
    'What would make a weekend fun for each of us?',
    'daily_life',
    null,
    'There is not enough shared evidence yet'
  ),
  (
    '47000000-0000-0000-0000-000000000004',
    '37000000-0000-0000-0000-000000000004',
    '27000000-0000-0000-0000-000000000001',
    '17000000-0000-0000-0000-000000000001',
    'direct_follow_up_walk_gh78ij90',
    'What kind of walk would each of us enjoy?',
    'daily_life',
    null,
    'There is not enough shared evidence yet'
  );

select ok(
  to_regclass('public.ai_user_question_follow_ups') is not null,
  'direct follow-up proposals have private lifecycle storage'
);
select ok(
  to_regprocedure(
    'public.decide_ai_user_question_follow_up(uuid,text)'
  ) is not null,
  'requesters can decide a direct follow-up through one RPC'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.ai_user_question_follow_ups',
    'SELECT'
  ),
  'clients cannot read proposal rows directly'
);

select set_config(
  'request.jwt.claim.sub',
  '17000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_my_ai_user_questions()
    ->'questions'->3->'follow_up'->>'status',
  'pending',
  'the requester sees their pending proposal in private history'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '17000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  jsonb_array_length(
    public.get_my_ai_user_questions()->'questions'
  ),
  0,
  'the partner cannot read the requester proposal'
);
select throws_ok(
  $$
    select public.decide_ai_user_question_follow_up(
      '37000000-0000-0000-0000-000000000001',
      'approve'
    )
  $$,
  'P0001',
  'ai_follow_up_not_found',
  'the partner cannot decide the requester proposal'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '17000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.decide_ai_user_question_follow_up(
    '37000000-0000-0000-0000-000000000001',
    'dismiss'
  )->>'status',
  'dismissed',
  'the requester can dismiss a proposal'
);

reset role;

select is(
  (
    select count(*)
    from public.ai_question_recommendations as aiqr
    where aiqr.source_follow_up_id =
      '47000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'dismissal creates no shared recommendation'
);

select set_config(
  'request.jwt.claim.sub',
  '17000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.decide_ai_user_question_follow_up(
    '37000000-0000-0000-0000-000000000002',
    'approve'
  )->>'status',
  'approved',
  'the requester can approve a safe proposal'
);
select is(
  public.decide_ai_user_question_follow_up(
    '37000000-0000-0000-0000-000000000002',
    'approve'
  )->>'status',
  'approved',
  'repeating the same approval is idempotent'
);

reset role;

select is(
  (
    select count(*)
    from public.ai_question_recommendations as aiqr
    where aiqr.source_follow_up_id =
      '47000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'an approved proposal enters the existing queue exactly once'
);

select set_config(
  'request.jwt.claim.sub',
  '17000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.decide_ai_user_question_follow_up(
    '37000000-0000-0000-0000-000000000003',
    'approve'
  )->>'status',
  'approved',
  'a second approved proposal fills the queue'
);

reset role;

select is(
  (
    select count(*)
    from public.ai_question_recommendations as aiqr
    where aiqr.couple_id =
      '27000000-0000-0000-0000-000000000001'
      and aiqr.status = 'pending'
  ),
  2::bigint,
  'the shared queue keeps at most two pending proposals'
);
select is(
  (
    select count(distinct q.question_key)
    from public.questions as q
    where q.approved_follow_up_id in (
      '47000000-0000-0000-0000-000000000002',
      '47000000-0000-0000-0000-000000000003'
    )
  ),
  2::bigint,
  'approved questions receive server-owned unique keys'
);

insert into public.questions (
  id,
  source,
  question_text,
  category,
  is_active
)
values (
  '68000000-0000-0000-0000-000000000001',
  'curated',
  'Which small moment felt most memorable today?',
  'daily_life',
  true
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '6a000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001',
  current_date,
  'waiting_partner_card'
);

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  story_loop_id,
  status
)
values (
  '69000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001',
  '68000000-0000-0000-0000-000000000001',
  current_date,
  '6a000000-0000-0000-0000-000000000001',
  'pending'
);

insert into public.ai_runs (
  id,
  couple_id,
  daily_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  safety_status,
  completed_at
)
values (
  '57000000-0000-0000-0000-000000000001',
  '27000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000001',
  'generate_general_question',
  'test',
  'test-model',
  'test-v1',
  'succeeded',
  'passed',
  now()
);

insert into public.questions (
  id,
  source,
  question_key,
  question_text,
  category,
  is_active,
  personalized_for_couple_id,
  generated_by_run_id
)
values (
  '67000000-0000-0000-0000-000000000001',
  'ai',
  'general_queue_overflow_ab12cd34',
  'What small thing would make today feel a little nicer?',
  'daily_life',
  true,
  '27000000-0000-0000-0000-000000000001',
  '57000000-0000-0000-0000-000000000001'
);

insert into public.ai_question_recommendations (
  couple_id,
  question_id,
  source_run_id,
  reason
)
values (
  '27000000-0000-0000-0000-000000000001',
  '67000000-0000-0000-0000-000000000001',
  '57000000-0000-0000-0000-000000000001',
  'queue capacity regression test'
);

select is(
  (
    select aiqr.status
    from public.ai_question_recommendations as aiqr
    where aiqr.source_run_id =
      '57000000-0000-0000-0000-000000000001'
  ),
  'expired',
  'a generated recommendation does not displace two approved proposals'
);
select is(
  (
    select q.is_active
    from public.questions as q
    where q.id = '67000000-0000-0000-0000-000000000001'
  ),
  false,
  'a generated question rejected by the full queue is deactivated'
);

select set_config(
  'request.jwt.claim.sub',
  '17000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  $$
    select public.decide_ai_user_question_follow_up(
      '37000000-0000-0000-0000-000000000004',
      'approve'
    )
  $$,
  'P0001',
  'ai_follow_up_queue_full',
  'a third explicit approval is not silently discarded'
);
select is(
  public.delete_my_ai_user_question(
    '37000000-0000-0000-0000-000000000002'
  ),
  true,
  'the requester can still delete approved private history'
);

reset role;

select is(
  (
    select aiuqfu.user_question_id
    from public.ai_user_question_follow_ups as aiuqfu
    where aiuqfu.id =
      '47000000-0000-0000-0000-000000000002'
  ),
  null::uuid,
  'deleting private history detaches the approved shared proposal'
);
select ok(
  exists (
    select 1
    from public.questions as q
    join public.ai_user_question_follow_ups as aiuqfu
      on aiuqfu.shared_question_id = q.id
    where aiuqfu.id =
      '47000000-0000-0000-0000-000000000002'
      and q.is_active
  ),
  'the approved shared question survives private history deletion'
);
select ok(
  exists (
    select 1
    from public.ai_question_recommendations as aiqr
    where aiqr.source_follow_up_id =
      '47000000-0000-0000-0000-000000000002'
      and aiqr.status = 'pending'
  ),
  'the approved queue item survives private history deletion'
);
select is(
  (
    select count(*)
    from public.questions as q
    where q.approved_follow_up_id is not null
      and q.generated_by_run_id is null
  ),
  2::bigint,
  'approved proposals use follow-up provenance instead of a model run'
);
select is(
  (
    select count(*)
    from public.ai_user_question_follow_ups as aiuqfu
    where aiuqfu.status = 'dismissed'
      and aiuqfu.shared_question_id is null
  ),
  1::bigint,
  'dismissed proposals remain private audit records only'
);
select is(
  (
    select count(*)
    from public.ai_user_question_follow_ups as aiuqfu
    where aiuqfu.status = 'pending'
  ),
  1::bigint,
  'a rejected third approval remains available for a later decision'
);

select * from finish();
rollback;
