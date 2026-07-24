begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(33);

create temporary table ai_direct_test_claim (
  job_id uuid,
  job_type text,
  run_id uuid
);
grant select, insert, update on table ai_direct_test_claim to service_role;

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
    '16000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'ai-direct-user-a@example.test',
    now(),
    now()
  ),
  (
    '16000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-direct-user-b@example.test',
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
  '26000000-0000-0000-0000-000000000001',
  'AIDIRECT',
  '16000000-0000-0000-0000-000000000001',
  '16000000-0000-0000-0000-000000000002',
  current_date - 10,
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
    '26000000-0000-0000-0000-000000000001',
    '16000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    now(),
    null
  ),
  (
    '26000000-0000-0000-0000-000000000001',
    '16000000-0000-0000-0000-000000000002',
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
  '26000000-0000-0000-0000-000000000001',
  aiqc.version,
  now()
from public.ai_question_curricula as aiqc
where aiqc.status = 'active'
order by aiqc.version desc
limit 1;

select ok(
  to_regclass('public.ai_user_questions') is not null,
  'direct questions have private storage'
);
select ok(
  to_regclass('public.ai_user_question_daily_usage') is not null,
  'direct question rate limits have independent storage'
);
select ok(
  to_regprocedure('public.submit_ai_user_question(text)') is not null,
  'direct question submit RPC exists'
);
select ok(
  to_regprocedure('public.get_my_ai_user_questions()') is not null,
  'direct question history RPC exists'
);
select ok(
  to_regprocedure('public.delete_my_ai_user_question(uuid)') is not null,
  'direct question deletion RPC exists'
);
select ok(
  to_regprocedure(
    'public.get_ai_direct_question_job_context(uuid)'
  ) is not null,
  'direct question worker context RPC exists'
);
select ok(
  to_regprocedure(
    'public.get_ai_proactive_suggestion_context(uuid)'
  ) is not null,
  'proactive suggestion context RPC exists'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.ai_user_questions',
    'SELECT'
  ),
  'clients cannot read direct question rows'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.get_ai_proactive_suggestion_context(uuid)',
    'EXECUTE'
  ),
  'clients cannot request another user proactive context'
);

select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_my_ai_user_questions()->>'remaining_count',
  '3',
  'a personalized member starts with three questions'
);
select throws_ok(
  $$
    select public.submit_ai_user_question(
      '상대방 연봉과 돈 관리는 어떻게 물어보면 좋을까?'
    )
  $$,
  'P0001',
  'ai_sensitive_question_not_available',
  'a sensitive direct question is rejected before using the daily allowance'
);
select is(
  public.submit_ai_user_question(
    '우리 둘은 쉬는 날에 어떤 시간을 보내면 잘 맞을까?'
  )->'question'->>'status',
  'queued',
  'a direct question enters the asynchronous queue'
);
select is(
  jsonb_array_length(
    public.get_my_ai_user_questions()->'questions'
  ),
  1,
  'the requester can read their private question'
);

reset role;

select ok(
  exists (
    select 1
    from public.ai_processing_jobs as aipj
    join public.ai_user_questions as aiuq
      on aiuq.id = aipj.user_question_id
    where aiuq.requester_user_id =
      '16000000-0000-0000-0000-000000000001'
      and aipj.job_type = 'answer_user_question'
      and aipj.status = 'pending'
  ),
  'a direct question creates one worker job'
);

select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  jsonb_array_length(
    public.get_my_ai_user_questions()->'questions'
  ),
  0,
  'the partner cannot read the requester history'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$
    do $test$
    begin
      perform public.submit_ai_user_question('두 번째 질문');
      perform public.submit_ai_user_question('세 번째 질문');
    end;
    $test$
  $$,
  'the requester can use the remaining two questions'
);
select is(
  public.get_my_ai_user_questions()->>'remaining_count',
  '0',
  'the daily allowance reaches zero after three submissions'
);
select throws_ok(
  $$
    select public.submit_ai_user_question('네 번째 질문')
  $$,
  'P0001',
  'ai_daily_question_limit_reached',
  'a fourth direct question is rejected'
);
select is(
  public.delete_my_ai_user_question(
    (
      public.get_my_ai_user_questions()
        ->'questions'->0->>'id'
    )::uuid
  ),
  true,
  'the requester can delete a private history item'
);
select is(
  jsonb_array_length(
    public.get_my_ai_user_questions()->'questions'
  ),
  2,
  'a deleted question no longer appears in history'
);
select is(
  public.get_my_ai_user_questions()->>'remaining_count',
  '0',
  'deleting history does not bypass the daily limit'
);

reset role;

select is(
  (
    select count(*)::integer
    from public.ai_user_questions
    where requester_user_id =
      '16000000-0000-0000-0000-000000000001'
  ),
  2,
  'deletion removes the question text from private storage'
);

set local role service_role;

select lives_ok(
  $$
    insert into pg_temp.ai_direct_test_claim (job_id, job_type)
    select claimed.job_id, claimed.job_type
    from public.claim_ai_processing_jobs(
      'ai-direct-contract-worker',
      1
    ) as claimed
  $$,
  'the worker can claim a direct question job'
);

reset role;

select is(
  (select job_type from pg_temp.ai_direct_test_claim),
  'answer_user_question',
  'the claimed work is a direct question'
);
select is(
  (
    select aiuq.status
    from public.ai_user_questions as aiuq
    join public.ai_processing_jobs as aipj
      on aipj.user_question_id = aiuq.id
    where aipj.claimed_by = 'ai-direct-contract-worker'
  ),
  'processing',
  'claiming a job updates the requester-visible status'
);

set local role service_role;

select ok(
  char_length(
    public.get_ai_direct_question_job_context(
      (select job_id from pg_temp.ai_direct_test_claim)
    )->>'question_text'
  ) > 0,
  'the worker receives the direct question text'
);
select is(
  jsonb_typeof(
    public.get_ai_direct_question_job_context(
      (select job_id from pg_temp.ai_direct_test_claim)
    )->'confirmed_memories'
  ),
  'array',
  'the worker receives only confirmed memory context'
);
select lives_ok(
  $$
    select public.start_ai_processing_run(
      (select job_id from pg_temp.ai_direct_test_claim),
      'google',
      'gemini-test',
      'direct-question-v1'
    )
  $$,
  'the worker can start a direct question run'
);

reset role;

update pg_temp.ai_direct_test_claim
set run_id = (
  select id
  from public.ai_runs
  where task = 'answer_user_question'
    and status = 'started'
);

set local role service_role;

select is(
  public.succeed_ai_processing_run(
    (select run_id from pg_temp.ai_direct_test_claim),
    '{"answer_text":"둘이 조용히 걷는 시간을 좋아한다고 했어"}'::jsonb,
    10,
    10,
    100
  ),
  true,
  'the worker atomically stores a direct answer'
);
select is(
  public.get_ai_proactive_suggestion_context(
    '16000000-0000-0000-0000-000000000001'
  )->>'has_card_today',
  'false',
  'proactive context reflects the requester card state'
);
select is(
  jsonb_typeof(
    public.get_ai_proactive_suggestion_context(
      '16000000-0000-0000-0000-000000000001'
    )->'confirmed_memories'
  ),
  'array',
  'proactive context contains confirmed memories without persistence'
);
select is(
  jsonb_typeof(
    public.get_ai_proactive_suggestion_context(
      '16000000-0000-0000-0000-000000000001'
    )->'recent_completed_questions'
  ),
  'array',
  'proactive context contains recent completed answers'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '16000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select ok(
  exists (
    select 1
    from jsonb_array_elements(
      public.get_my_ai_user_questions()->'questions'
    ) as item
    where item->>'status' = 'completed'
      and item->>'answer_text' =
        '둘이 조용히 걷는 시간을 좋아한다고 했어'
  ),
  'the requester can read the completed answer'
);

select * from finish();
rollback;
