begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(49);

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

insert into public.user_policy_acceptances (
  user_id,
  policy_type,
  policy_version
)
values
  (
    '16000000-0000-0000-0000-000000000001',
    'ugc_safety_policy',
    'ugc-safety-v1'
  ),
  (
    '16000000-0000-0000-0000-000000000002',
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
  'a personalized member starts with the release allowance'
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
  'the requester can use the final two questions at the limit'
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
  'a question beyond the configured daily limit is rejected'
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
select is(
  jsonb_typeof(
    public.get_ai_direct_question_job_context(
      (select job_id from pg_temp.ai_direct_test_claim)
    )->'recent_shared_questions'
  ),
  'array',
  'the worker receives recent shared questions for duplicate prevention'
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
    jsonb_build_object(
      'answer_status', 'insufficient',
      'answer_text', 'I do not know enough yet',
      'follow_up_question', jsonb_build_object(
        'question_key', 'direct_follow_up_shared_walk_ab12cd34',
        'question_text', 'What kind of walk would each of us enjoy?',
        'category', 'daily_life',
        'mood', 'light',
        'rationale', 'There is not enough shared evidence yet'
      )
    ),
    10,
    10,
    100
  ),
  true,
  'the worker atomically stores a direct answer'
);

reset role;

select is(
  (
    select aiuq.result_kind
    from public.ai_user_questions as aiuq
    where aiuq.id = (
      select aipj.user_question_id
      from public.ai_processing_jobs as aipj
      where aipj.id = (select job_id from pg_temp.ai_direct_test_claim)
    )
  ),
  'insufficient',
  'the completed answer records its structured result kind'
);
select is(
  (
    select count(*)
    from public.ai_user_question_follow_ups as aiuqfu
    where aiuqfu.user_question_id = (
      select aipj.user_question_id
      from public.ai_processing_jobs as aipj
      where aipj.id = (select job_id from pg_temp.ai_direct_test_claim)
    )
      and aiuqfu.status = 'pending'
  ),
  1::bigint,
  'a safe insufficient answer stores one private follow-up proposal'
);
select is(
  (
    select aiuq.follow_up_outcome
    from public.ai_user_questions as aiuq
    where aiuq.id = (
      select aipj.user_question_id
      from public.ai_processing_jobs as aipj
      where aipj.id = (select job_id from pg_temp.ai_direct_test_claim)
    )
  ),
  'created',
  'a stored follow-up records its final outcome'
);
select is(
  (
    select aiuq.follow_up_error_code
    from public.ai_user_questions as aiuq
    where aiuq.id = (
      select aipj.user_question_id
      from public.ai_processing_jobs as aipj
      where aipj.id = (select job_id from pg_temp.ai_direct_test_claim)
    )
  ),
  null,
  'a stored follow-up has no validation error'
);
select is(
  (
    select count(*)
    from public.app_notification_events as ane
    where ane.event_type = 'ai_direct_answer_ready'
      and ane.payload->>'user_question_id' is not null
  ),
  1::bigint,
  'a completed direct answer creates one notification event'
);
select is(
  (
    select ane.receiver_user_id
    from public.app_notification_events as ane
    where ane.event_type = 'ai_direct_answer_ready'
  ),
  '16000000-0000-0000-0000-000000000001'::uuid,
  'the direct answer notification belongs only to its requester'
);
select is(
  (
    select ane.payload->>'result_status'
    from public.app_notification_events as ane
    where ane.event_type = 'ai_direct_answer_ready'
  ),
  'completed',
  'the direct answer notification records its terminal result'
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
      and item->>'answer_text' = 'I do not know enough yet'
  ),
  'the requester can read the completed answer'
);
select ok(
  exists (
    select 1
    from jsonb_array_elements(
      public.get_my_ai_user_questions()->'questions'
    ) as item
    where item->>'status' = 'completed'
      and item->'follow_up'->>'status' = 'pending'
  ),
  'the requester sees the private proposal with the completed answer'
);

reset role;

update public.ai_processing_jobs as aipj
set
  status = 'failed',
  completed_at = now(),
  last_error = 'ai_answer_failed'
where aipj.id = (
  select pending_job.id
  from public.ai_processing_jobs as pending_job
  join public.ai_user_questions as aiuq
    on aiuq.id = pending_job.user_question_id
  where aiuq.requester_user_id =
      '16000000-0000-0000-0000-000000000001'
    and pending_job.job_type = 'answer_user_question'
    and pending_job.status = 'pending'
  order by pending_job.created_at, pending_job.id
  limit 1
);

select is(
  (
    select count(*)
    from public.app_notification_events as ane
    where ane.event_type = 'ai_direct_answer_failed'
  ),
  1::bigint,
  'a final direct answer failure creates one notification event'
);
select is(
  (
    select ane.receiver_user_id
    from public.app_notification_events as ane
    where ane.event_type = 'ai_direct_answer_failed'
  ),
  '16000000-0000-0000-0000-000000000001'::uuid,
  'the direct answer failure notification belongs only to its requester'
);
select is(
  (
    select ane.payload->>'result_status'
    from public.app_notification_events as ane
    where ane.event_type = 'ai_direct_answer_failed'
  ),
  'failed',
  'the failure notification is emitted only for the terminal state'
);

insert into public.ai_user_questions (
  id,
  couple_id,
  requester_user_id,
  question_text,
  status
)
values (
  '36000000-0000-0000-0000-000000000099',
  '26000000-0000-0000-0000-000000000001',
  '16000000-0000-0000-0000-000000000001',
  'Does my partner prefer an early travel morning?',
  'processing'
);

insert into public.ai_processing_jobs (
  id,
  couple_id,
  user_question_id,
  job_type,
  status,
  deduplication_key,
  attempts,
  claimed_at,
  claimed_by,
  lease_expires_at
)
values (
  '46000000-0000-0000-0000-000000000099',
  '26000000-0000-0000-0000-000000000001',
  '36000000-0000-0000-0000-000000000099',
  'answer_user_question',
  'processing',
  'direct-question-outcome-test',
  1,
  now(),
  'ai-direct-outcome-worker',
  now() + interval '5 minutes'
);

create temporary table ai_direct_outcome_run (
  run_id uuid
);
grant select, insert on table ai_direct_outcome_run to service_role;

set local role service_role;

select lives_ok(
  $$
    insert into pg_temp.ai_direct_outcome_run (run_id)
    select public.start_ai_processing_run(
        '46000000-0000-0000-0000-000000000099',
        'google',
        'gemini-test',
        'direct-question-v5'
      )
  $$,
  'an unavailable follow-up run can start'
);

select is(
  public.succeed_ai_processing_run(
    (
      select test_run.run_id
      from pg_temp.ai_direct_outcome_run as test_run
    ),
    jsonb_build_object(
      'answer_status', 'insufficient',
      'answer_text', 'There is not enough evidence yet',
      'follow_up_generation_status', 'generation_failed',
      'follow_up_error_code', 'model_generation_failed',
      'follow_up_question', null
    ),
    10,
    10,
    100
  ),
  true,
  'an answer remains successful when follow-up generation is unavailable'
);

select is(
  (
    select aiuq.follow_up_outcome
    from public.ai_user_questions as aiuq
    where aiuq.id = '36000000-0000-0000-0000-000000000099'
  ),
  'generation_failed',
  'an unavailable follow-up records a diagnosable outcome'
);
select is(
  (
    select aiuq.follow_up_error_code
    from public.ai_user_questions as aiuq
    where aiuq.id = '36000000-0000-0000-0000-000000000099'
  ),
  'model_generation_failed',
  'an unavailable follow-up records a safe detailed error code'
);

select * from finish();
rollback;
