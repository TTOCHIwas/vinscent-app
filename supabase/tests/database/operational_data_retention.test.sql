begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(31);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '61000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'retention-a@example.test',
    now(),
    now()
  ),
  (
    '61000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'retention-b@example.test',
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
  '62000000-0000-0000-0000-000000000001',
  'RET001',
  '61000000-0000-0000-0000-000000000001',
  '61000000-0000-0000-0000-000000000002',
  current_date - 10,
  'active',
  now(),
  'default'
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
  '62500000-0000-0000-0000-000000000001',
  '62000000-0000-0000-0000-000000000001',
  current_date - 1,
  'question_generated',
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
  '62600000-0000-0000-0000-000000000001',
  '62000000-0000-0000-0000-000000000001',
  question.id,
  current_date - 1,
  'pending',
  '62500000-0000-0000-0000-000000000001'
from public.questions as question
where question.curriculum_version = 1
  and question.curriculum_position = 1;

insert into public.ai_processing_jobs (
  id,
  couple_id,
  daily_question_id,
  job_type,
  status,
  deduplication_key,
  attempts,
  completed_at,
  created_at,
  updated_at
)
values
  (
    '63000000-0000-0000-0000-000000000001',
    '62000000-0000-0000-0000-000000000001',
    '62600000-0000-0000-0000-000000000001',
    'extract_memories',
    'succeeded',
    'retention:referenced',
    1,
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days'
  ),
  (
    '63000000-0000-0000-0000-000000000002',
    '62000000-0000-0000-0000-000000000001',
    '62600000-0000-0000-0000-000000000001',
    'extract_memories',
    'failed',
    'retention:unreferenced',
    3,
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days'
  ),
  (
    '63000000-0000-0000-0000-000000000003',
    '62000000-0000-0000-0000-000000000001',
    '62600000-0000-0000-0000-000000000001',
    'extract_memories',
    'succeeded',
    'retention:fresh',
    1,
    now() - interval '89 days',
    now() - interval '89 days',
    now() - interval '89 days'
  ),
  (
    '63000000-0000-0000-0000-000000000004',
    '62000000-0000-0000-0000-000000000001',
    '62600000-0000-0000-0000-000000000001',
    'extract_memories',
    'pending',
    'retention:pending',
    0,
    null,
    now() - interval '120 days',
    now() - interval '120 days'
  );

insert into public.ai_runs (
  id,
  job_id,
  couple_id,
  daily_question_id,
  task,
  provider,
  model,
  prompt_version,
  status,
  input_answer_ids,
  input_token_count,
  output_token_count,
  latency_ms,
  safety_status,
  error_code,
  provider_http_status,
  provider_error_status,
  provider_error_detail,
  provider_retry_after_ms,
  started_at,
  completed_at,
  created_at
)
values
  (
    '64000000-0000-0000-0000-000000000001',
    '63000000-0000-0000-0000-000000000001',
    '62000000-0000-0000-0000-000000000001',
    '62600000-0000-0000-0000-000000000001',
    'extract_memories',
    'cloudflare',
    'retention-model',
    'retention-v1',
    'succeeded',
    array['65000000-0000-0000-0000-000000000001'::uuid],
    120,
    40,
    800,
    'passed',
    'transient_error',
    503,
    'UNAVAILABLE',
    'temporary provider detail',
    1000,
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days'
  ),
  (
    '64000000-0000-0000-0000-000000000002',
    '63000000-0000-0000-0000-000000000002',
    '62000000-0000-0000-0000-000000000001',
    '62600000-0000-0000-0000-000000000001',
    'extract_memories',
    'cloudflare',
    'retention-model',
    'retention-v1',
    'failed',
    '{}'::uuid[],
    20,
    0,
    200,
    'error',
    'provider_error',
    500,
    'INTERNAL',
    'old failed run',
    null,
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days'
  ),
  (
    '64000000-0000-0000-0000-000000000003',
    '63000000-0000-0000-0000-000000000003',
    '62000000-0000-0000-0000-000000000001',
    '62600000-0000-0000-0000-000000000001',
    'extract_memories',
    'cloudflare',
    'retention-model',
    'retention-v1',
    'succeeded',
    '{}'::uuid[],
    100,
    20,
    500,
    'passed',
    null,
    null,
    null,
    null,
    null,
    now() - interval '89 days',
    now() - interval '89 days',
    now() - interval '89 days'
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
  last_observed_at,
  created_at,
  updated_at
)
values (
  '66000000-0000-0000-0000-000000000001',
  '62000000-0000-0000-0000-000000000001',
  'couple',
  null,
  'retention-memory',
  'explicit',
  '보존되어야 하는 기억',
  1,
  'active',
  '64000000-0000-0000-0000-000000000001',
  now() - interval '91 days',
  now() - interval '91 days',
  now() - interval '91 days',
  now() - interval '91 days'
);

insert into public.push_notification_dispatches (
  notification_type,
  source_id,
  receiver_user_id,
  status,
  claimed_at,
  completed_at,
  created_at,
  updated_at,
  attempt_count,
  max_attempts
)
values
  (
    'recording_activity',
    '67000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001',
    'sent',
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days',
    1,
    5
  ),
  (
    'recording_activity',
    '67000000-0000-0000-0000-000000000002',
    '61000000-0000-0000-0000-000000000001',
    'failed',
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days',
    now() - interval '91 days',
    1,
    5
  ),
  (
    'recording_activity',
    '67000000-0000-0000-0000-000000000003',
    '61000000-0000-0000-0000-000000000001',
    'sent',
    now() - interval '89 days',
    now() - interval '89 days',
    now() - interval '89 days',
    now() - interval '89 days',
    1,
    5
  );

insert into public.push_notification_deliveries (
  id,
  notification_type,
  source_id,
  receiver_user_id,
  target_token_count,
  success_count,
  failure_count,
  status,
  created_at
)
values
  (
    '68000000-0000-0000-0000-000000000001',
    'recording_activity',
    '67000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001',
    1,
    1,
    0,
    'sent',
    now() - interval '91 days'
  ),
  (
    '68000000-0000-0000-0000-000000000002',
    'recording_activity',
    '67000000-0000-0000-0000-000000000002',
    '61000000-0000-0000-0000-000000000001',
    1,
    0,
    1,
    'failed',
    now() - interval '91 days'
  ),
  (
    '68000000-0000-0000-0000-000000000003',
    'recording_activity',
    '67000000-0000-0000-0000-000000000003',
    '61000000-0000-0000-0000-000000000001',
    1,
    1,
    0,
    'sent',
    now() - interval '89 days'
  );

insert into public.safety_reports (
  id,
  reporter_user_id,
  reported_user_id,
  couple_id,
  target_type,
  target_id,
  reason,
  status,
  reviewed_at,
  reviewed_by,
  created_at,
  updated_at
)
values
  (
    '69000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000002',
    '62000000-0000-0000-0000-000000000001',
    'partner',
    '61000000-0000-0000-0000-000000000002',
    'harassment',
    'reviewed',
    now() - interval '1 year 1 day',
    'retention-reviewer',
    now() - interval '1 year 2 days',
    now() - interval '1 year 1 day'
  ),
  (
    '69000000-0000-0000-0000-000000000002',
    '61000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000002',
    '62000000-0000-0000-0000-000000000001',
    'ai_feedback',
    'fresh-safety-feedback',
    'unsafe_ai',
    'reviewed',
    now() - interval '364 days',
    'retention-reviewer',
    now() - interval '365 days',
    now() - interval '364 days'
  ),
  (
    '69000000-0000-0000-0000-000000000003',
    '61000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000002',
    '62000000-0000-0000-0000-000000000001',
    'ai_direct_answer',
    'pending-safety-answer',
    'unsafe_ai',
    'pending',
    null,
    null,
    now() - interval '2 years',
    now() - interval '2 years'
  );

insert into public.safety_report_reviews (
  id,
  report_id,
  decision_status,
  reviewer_id,
  reviewed_at
)
values (
  '6a000000-0000-0000-0000-000000000001',
  '69000000-0000-0000-0000-000000000001',
  'reviewed',
  'retention-reviewer',
  now() - interval '1 year 1 day'
);

select ok(
  to_regprocedure(
    'private.purge_expired_operational_records(timestamp with time zone,integer)'
  ) is not null,
  'operational retention cleanup exists'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'private.purge_expired_operational_records(timestamp with time zone,integer)',
    'EXECUTE'
  ),
  'clients cannot run operational retention cleanup'
);
select is(
  (
    select schedule
    from cron.job
    where jobname = 'purge-expired-operational-records'
  ),
  '17 18 * * *',
  'operational retention cleanup runs daily at 03:17 KST'
);

create temporary table retention_result as
select *
from private.purge_expired_operational_records(now(), 5000);

select is(
  (select redacted_ai_run_count from retention_result),
  1,
  'one referenced AI run has diagnostic fields redacted'
);
select is(
  (select deleted_ai_run_count from retention_result),
  1,
  'one unreferenced AI run is deleted'
);
select is(
  (select deleted_ai_job_count from retention_result),
  2,
  'old terminal AI jobs are deleted'
);
select is(
  (select deleted_push_delivery_count from retention_result),
  1,
  'one old terminal push delivery is deleted'
);
select is(
  (select deleted_push_dispatch_count from retention_result),
  1,
  'one old terminal push dispatch is deleted'
);
select is(
  (select deleted_safety_report_count from retention_result),
  1,
  'one old reviewed safety report is deleted'
);
select ok(
  exists (
    select 1
    from public.ai_runs
    where id = '64000000-0000-0000-0000-000000000001'
  ),
  'a run referenced by a retained memory remains available'
);
select is(
  (
    select cardinality(input_answer_ids)
    from public.ai_runs
    where id = '64000000-0000-0000-0000-000000000001'
  ),
  0,
  'retained AI provenance no longer keeps answer identifiers'
);
select ok(
  (
    select input_token_count is null
      and output_token_count is null
      and latency_ms is null
      and error_code is null
      and provider_http_status is null
      and provider_error_status is null
      and provider_error_detail is null
      and provider_retry_after_ms is null
    from public.ai_runs
    where id = '64000000-0000-0000-0000-000000000001'
  ),
  'retained AI provenance has no detailed diagnostics'
);
select results_eq(
  $$
    select provider, model, prompt_version, status, safety_status
    from public.ai_runs
    where id = '64000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('cloudflare', 'retention-model', 'retention-v1', 'succeeded', 'passed') $$,
  'minimal AI provenance remains unchanged'
);
select ok(
  not exists (
    select 1
    from public.ai_runs
    where id = '64000000-0000-0000-0000-000000000002'
  ),
  'unreferenced expired AI runs are removed'
);
select ok(
  exists (
    select 1
    from public.ai_runs
    where id = '64000000-0000-0000-0000-000000000003'
  ),
  'AI runs inside the retention period remain unchanged'
);
select ok(
  exists (
    select 1
    from public.ai_processing_jobs
    where id = '63000000-0000-0000-0000-000000000003'
  ),
  'fresh terminal AI jobs remain available'
);
select ok(
  exists (
    select 1
    from public.ai_processing_jobs
    where id = '63000000-0000-0000-0000-000000000004'
  ),
  'pending AI jobs are never removed by retention cleanup'
);
select ok(
  not exists (
    select 1
    from public.push_notification_dispatches
    where source_id = '67000000-0000-0000-0000-000000000001'
  ),
  'expired terminal push dispatches are removed'
);
select ok(
  exists (
    select 1
    from public.push_notification_dispatches
    where source_id = '67000000-0000-0000-0000-000000000002'
  ),
  'retryable push dispatches are preserved'
);
select ok(
  exists (
    select 1
    from public.push_notification_dispatches
    where source_id = '67000000-0000-0000-0000-000000000003'
  ),
  'push dispatches inside the retention period remain available'
);
select ok(
  not exists (
    select 1
    from public.push_notification_deliveries
    where id = '68000000-0000-0000-0000-000000000001'
  ),
  'expired terminal push delivery logs are removed'
);
select ok(
  exists (
    select 1
    from public.push_notification_deliveries
    where id = '68000000-0000-0000-0000-000000000002'
  ),
  'delivery logs required by a retryable dispatch are preserved'
);
select ok(
  exists (
    select 1
    from public.push_notification_deliveries
    where id = '68000000-0000-0000-0000-000000000003'
  ),
  'fresh push delivery logs remain available'
);
select ok(
  not exists (
    select 1
    from public.safety_reports
    where id = '69000000-0000-0000-0000-000000000001'
  ),
  'reviewed safety reports older than one year are removed'
);
select ok(
  not exists (
    select 1
    from public.safety_report_reviews
    where report_id = '69000000-0000-0000-0000-000000000001'
  ),
  'review audit rows follow the safety report lifecycle'
);
select ok(
  not exists (
    select 1
    from public.safety_moderation_alerts
    where report_id = '69000000-0000-0000-0000-000000000001'
  ),
  'moderation alert rows follow the safety report lifecycle'
);
select ok(
  exists (
    select 1
    from public.safety_reports
    where id = '69000000-0000-0000-0000-000000000002'
  ),
  'reviewed safety reports inside one year remain available'
);
select ok(
  exists (
    select 1
    from public.safety_reports
    where id = '69000000-0000-0000-0000-000000000003'
  ),
  'pending safety reports remain regardless of age'
);

select lives_ok(
  $$ select * from private.purge_expired_operational_records(now(), 5000) $$,
  'retention cleanup is idempotent'
);
select is(
  (
    select count(*)
    from private.purge_expired_operational_records(now(), 5000)
    where redacted_ai_run_count <> 0
      or deleted_ai_run_count <> 0
      or deleted_ai_job_count <> 0
      or deleted_push_delivery_count <> 0
      or deleted_push_dispatch_count <> 0
      or deleted_safety_report_count <> 0
  ),
  0::bigint,
  'repeated retention cleanup reports no additional changes'
);

select throws_ok(
  $$ select * from private.purge_expired_operational_records(now(), 0) $$,
  'P0001',
  'invalid_retention_batch_size',
  'retention cleanup rejects invalid batch sizes'
);

select * from finish();
rollback;
