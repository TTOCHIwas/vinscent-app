begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(31);

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
    'ai-worker-a@example.test',
    now(),
    now()
  ),
  (
    '11000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'ai-worker-b@example.test',
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
  'AIWORK01',
  '11000000-0000-0000-0000-000000000001',
  '11000000-0000-0000-0000-000000000002',
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
  revision,
  granted_at,
  revoked_at
)
values
  (
    '21000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    'granted',
    'ai-learning-v1',
    1,
    now(),
    null
  ),
  (
    '21000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000002',
    'granted',
    'ai-learning-v1',
    1,
    now(),
    null
  );

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status,
  question_generated_at,
  story_edit_locked_at
)
values (
  '31000000-0000-0000-0000-000000000001',
  '21000000-0000-0000-0000-000000000001',
  current_date - 1,
  'answered_by_one',
  now(),
  now()
);

insert into public.daily_questions (
  id,
  couple_id,
  question_id,
  assigned_date,
  status,
  story_loop_id
)
select
  '41000000-0000-0000-0000-000000000001',
  '21000000-0000-0000-0000-000000000001',
  q.id,
  current_date - 1,
  'answered_by_one',
  '31000000-0000-0000-0000-000000000001'
from public.questions as q
where q.curriculum_version = 1
  and q.curriculum_position = 1;

insert into public.daily_question_answers (
  id,
  daily_question_id,
  user_id,
  answer_text
)
values
  (
    '51000000-0000-0000-0000-000000000001',
    '41000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    'I value quiet time together.'
  ),
  (
    '51000000-0000-0000-0000-000000000002',
    '41000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000002',
    'I value trying new things together.'
  );

update public.daily_questions
set status = 'completed'
where id = '41000000-0000-0000-0000-000000000001';

insert into public.ai_runs (
  id,
  couple_id,
  daily_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  input_answer_ids,
  safety_status,
  completed_at
)
values (
  '61000000-0000-0000-0000-000000000001',
  '21000000-0000-0000-0000-000000000001',
  '41000000-0000-0000-0000-000000000001',
  'extract_memories',
  'fixture',
  'fixture',
  'fixture-v1',
  'succeeded',
  array['51000000-0000-0000-0000-000000000001'::uuid],
  'passed',
  now()
);

insert into public.ai_memories (
  id,
  couple_id,
  scope,
  subject_user_id,
  memory_key,
  kind,
  statement,
  confidence,
  state,
  source_run_id,
  observed_at,
  last_observed_at
)
values
  (
    '71000000-0000-0000-0000-000000000001',
    '21000000-0000-0000-0000-000000000001',
    'personal',
    '11000000-0000-0000-0000-000000000001',
    'partner_a_quiet_time',
    'personal_value',
    'Partner A values quiet time together.',
    0.8,
    'active',
    '61000000-0000-0000-0000-000000000001',
    now(),
    now()
  ),
  (
    '71000000-0000-0000-0000-000000000002',
    '21000000-0000-0000-0000-000000000001',
    'couple',
    null,
    'unconfirmed_fixture',
    'relationship_pattern',
    'This pending memory must not reach the model.',
    0.6,
    'pending',
    '61000000-0000-0000-0000-000000000001',
    now(),
    now()
  );

insert into public.ai_processing_jobs (
  id,
  couple_id,
  daily_question_id,
  job_type,
  status,
  deduplication_key,
  attempts,
  claimed_at,
  claimed_by,
  lease_expires_at
)
values
  (
    '81000000-0000-0000-0000-000000000001',
    '21000000-0000-0000-0000-000000000001',
    '41000000-0000-0000-0000-000000000001',
    'extract_memories',
    'processing',
    'worker-boundary:extract',
    1,
    now(),
    'test-worker',
    now() + interval '5 minutes'
  ),
  (
    '81000000-0000-0000-0000-000000000002',
    '21000000-0000-0000-0000-000000000001',
    '41000000-0000-0000-0000-000000000001',
    'generate_feedback',
    'processing',
    'worker-boundary:feedback',
    1,
    now(),
    'test-worker',
    now() + interval '5 minutes'
  ),
  (
    '81000000-0000-0000-0000-000000000003',
    '21000000-0000-0000-0000-000000000001',
    '41000000-0000-0000-0000-000000000001',
    'select_curated_question',
    'processing',
    'worker-boundary:select',
    1,
    now(),
    'test-worker',
    now() + interval '5 minutes'
  ),
  (
    '81000000-0000-0000-0000-000000000004',
    '21000000-0000-0000-0000-000000000001',
    '41000000-0000-0000-0000-000000000001',
    'generate_feedback',
    'processing',
    'worker-boundary:failure',
    1,
    now(),
    'test-worker',
    now() + interval '5 minutes'
  ),
  (
    '81000000-0000-0000-0000-000000000005',
    '21000000-0000-0000-0000-000000000001',
    null,
    'rebuild_profile',
    'processing',
    'worker-boundary:rebuild',
    1,
    now(),
    'test-worker',
    now() + interval '5 minutes'
  );

create temporary table ai_worker_test_values (
  value_key text primary key,
  value_uuid uuid not null
) on commit drop;

select is(
  public.get_ai_processing_job_context(
    '81000000-0000-0000-0000-000000000001'
  )->'answers'->0->>'user_id',
  '11000000-0000-0000-0000-000000000001'::text,
  'worker context orders partner A first'
);

select is(
  public.get_ai_processing_job_context(
    '81000000-0000-0000-0000-000000000001'
  )->'answers'->1->>'user_id',
  '11000000-0000-0000-0000-000000000002'::text,
  'worker context orders partner B second'
);

select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      '81000000-0000-0000-0000-000000000001'
    )->'confirmed_memories'
  ),
  1,
  'worker context contains active memories only'
);

select is(
  jsonb_array_length(
    public.get_ai_processing_job_context(
      '81000000-0000-0000-0000-000000000001'
    )->'remaining_foundation_questions'
  ),
  23,
  'worker context contains unused foundation questions'
);

insert into ai_worker_test_values (value_key, value_uuid)
select
  'extract_run',
  public.start_ai_processing_run(
    '81000000-0000-0000-0000-000000000001',
    'google',
    'gemini-test',
    'memory-v1'
  );

select ok(
  (select value_uuid from ai_worker_test_values where value_key = 'extract_run')
    is not null,
  'worker can start an extraction run'
);

select is(
  (
    select cardinality(air.input_answer_ids)
    from public.ai_runs as air
    where air.id = (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'extract_run'
    )
  ),
  2,
  'started run records both input answers'
);

select is(
  public.succeed_ai_processing_run(
    (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'extract_run'
    ),
    jsonb_build_object(
      'memories',
      jsonb_build_array(
        jsonb_build_object(
          'memory_key', 'partner_a_quality_time',
          'scope', 'personal',
          'subject_user_id', '11000000-0000-0000-0000-000000000001',
          'kind', 'personal_value',
          'statement', 'Partner A values quiet time together.',
          'confidence', 0.91,
          'evidence_answer_ids', jsonb_build_array(
            '51000000-0000-0000-0000-000000000001'
          )
        )
      )
    ),
    120,
    40,
    250
  ),
  true,
  'worker can atomically persist extracted memories'
);

select is(
  (
    select aim.state
    from public.ai_memories as aim
    where aim.memory_key = 'partner_a_quality_time'
  ),
  'pending'::text,
  'new memory requires confirmation'
);

select is(
  (
    select count(*)
    from public.ai_memory_evidence as aime
    join public.ai_memories as aim on aim.id = aime.memory_id
    where aim.memory_key = 'partner_a_quality_time'
  ),
  1::bigint,
  'memory evidence is persisted with the memory'
);

select is(
  (
    select aipj.status
    from public.ai_processing_jobs as aipj
    where aipj.id = '81000000-0000-0000-0000-000000000001'
  ),
  'succeeded'::text,
  'successful result completes the claimed job'
);

insert into ai_worker_test_values (value_key, value_uuid)
select
  'feedback_run',
  public.start_ai_processing_run(
    '81000000-0000-0000-0000-000000000002',
    'google',
    'gemini-test',
    'feedback-v1'
  );

select ok(
  (select value_uuid from ai_worker_test_values where value_key = 'feedback_run')
    is not null,
  'worker can start a feedback run'
);

select is(
  public.succeed_ai_processing_run(
    (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'feedback_run'
    ),
    jsonb_build_object(
      'feedback_text',
      'You value different moments and can make room for both.'
    ),
    100,
    24,
    180
  ),
  true,
  'worker can atomically publish feedback'
);

select is(
  (
    select aiqf.state
    from public.ai_question_feedbacks as aiqf
    where aiqf.daily_question_id =
      '41000000-0000-0000-0000-000000000001'
  ),
  'published'::text,
  'successful feedback is immediately readable'
);

select set_config(
  'request.jwt.claim.sub',
  '11000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  public.get_ai_question_feedback(
    '41000000-0000-0000-0000-000000000001'
  )->>'feedback_text',
  'You value different moments and can make room for both.'::text,
  'a couple member can read published question feedback'
);

reset role;

insert into ai_worker_test_values (value_key, value_uuid)
select
  'select_run',
  public.start_ai_processing_run(
    '81000000-0000-0000-0000-000000000003',
    'google',
    'gemini-test',
    'question-ranking-v1'
  );

select ok(
  (select value_uuid from ai_worker_test_values where value_key = 'select_run')
    is not null,
  'worker can start a foundation question ranking run'
);

select is(
  public.succeed_ai_processing_run(
    (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'select_run'
    ),
    jsonb_build_object(
      'question_key', 'foundation_v1_personal_values_02',
      'rationale', 'This question complements the latest answers.'
    ),
    140,
    30,
    220
  ),
  true,
  'worker can atomically record a foundation recommendation'
);

select is(
  (
    select q.question_key
    from public.ai_question_recommendations as aiqr
    join public.questions as q on q.id = aiqr.question_id
    where aiqr.couple_id = '21000000-0000-0000-0000-000000000001'
      and aiqr.status = 'pending'
  ),
  'foundation_v1_personal_values_02'::text,
  'recommendation points to the validated unused question'
);

insert into ai_worker_test_values (value_key, value_uuid)
select
  'failure_run',
  public.start_ai_processing_run(
    '81000000-0000-0000-0000-000000000004',
    'google',
    'gemini-test',
    'feedback-v1'
  );

select ok(
  (select value_uuid from ai_worker_test_values where value_key = 'failure_run')
    is not null,
  'worker can start a run that later fails'
);

select is(
  public.fail_ai_processing_run_with_diagnostics(
    (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'failure_run'
    ),
    'provider_unavailable',
    'error',
    true,
    null,
    null,
    300,
    429,
    'RESOURCE_EXHAUSTED',
    120000
  ),
  true,
  'worker can record a retryable provider failure'
);

select is(
  (
    select air.status
    from public.ai_runs as air
    where air.id = (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'failure_run'
    )
  ),
  'failed'::text,
  'failed model invocation closes its run'
);

select is(
  (
    select aipj.status
    from public.ai_processing_jobs as aipj
    where aipj.id = '81000000-0000-0000-0000-000000000004'
  ),
  'pending'::text,
  'retryable failure returns the job to the queue'
);

select is(
  (
    select air.provider_http_status
    from public.ai_runs as air
    where air.id = (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'failure_run'
    )
  ),
  429,
  'provider HTTP status is retained without storing response content'
);

select is(
  (
    select air.provider_error_status
    from public.ai_runs as air
    where air.id = (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'failure_run'
    )
  ),
  'RESOURCE_EXHAUSTED'::text,
  'bounded provider error status is retained'
);

select is(
  (
    select air.provider_retry_after_ms
    from public.ai_runs as air
    where air.id = (
      select value_uuid
      from ai_worker_test_values
      where value_key = 'failure_run'
    )
  ),
  120000,
  'provider retry delay is retained'
);

select ok(
  (
    select aipj.available_at > now() + interval '90 seconds'
    from public.ai_processing_jobs as aipj
    where aipj.id = '81000000-0000-0000-0000-000000000004'
  ),
  'retry honors provider delay and does not immediately burst again'
);

select is(
  (
    select aipj.max_attempts
    from public.ai_processing_jobs as aipj
    where aipj.id = '81000000-0000-0000-0000-000000000004'
  ),
  5,
  'AI jobs receive enough attempts for exponential provider backoff'
);

select is(
  public.expand_ai_rebuild_profile_job(
    '81000000-0000-0000-0000-000000000005'
  ),
  true,
  'worker can expand a consent rebuild into question jobs'
);

select is(
  (
    select aipj.status
    from public.ai_processing_jobs as aipj
    where aipj.id = '81000000-0000-0000-0000-000000000005'
  ),
  'succeeded'::text,
  'expanded rebuild job completes without a model invocation'
);

select is(
  (
    select count(*)
    from public.ai_processing_jobs as aipj
    where aipj.deduplication_key like
      'rebuild:81000000-0000-0000-0000-000000000005:%'
  ),
  3::bigint,
  'rebuild queues memory, feedback, and next-question work'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.get_ai_processing_job_context(uuid)',
    'EXECUTE'
  ),
  'service role can execute worker context RPC'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.get_ai_processing_job_context(uuid)',
    'EXECUTE'
  ),
  'authenticated users cannot execute worker context RPC'
);

select * from finish();
rollback;
