with expected_webhooks (
  trigger_name,
  table_schema,
  table_name,
  expected_event,
  function_name,
  header_name
) as (
  values
    (
      'send-story-loop-notification',
      'public',
      'story_loop_notification_events',
      'after insert',
      'send-story-loop-notification',
      'x-story-loop-webhook-secret'
    ),
    (
      'send-answer-complete-notification',
      'public',
      'daily_question_answers',
      'after insert',
      'send-answer-complete-notification',
      'x-answer-webhook-secret'
    ),
    (
      'send-recording-notification',
      'public',
      'recording_notification_events',
      'after insert',
      'send-recording-notification',
      'x-recording-webhook-secret'
    ),
    (
      'send-couple-disconnect-notification',
      'public',
      'couples',
      'after update',
      'send-couple-disconnect-notification',
      'x-couple-webhook-secret'
    ),
    (
      'send-app-notification',
      'public',
      'app_notification_events',
      'after insert',
      'send-app-notification',
      'x-app-notification-webhook-secret'
    ),
    (
      'process-storage-cleanup',
      'public',
      'storage_cleanup_requests',
      'after insert',
      'process-storage-cleanup',
      'x-storage-cleanup-webhook-secret'
    )
),
actual_webhooks as (
  select
    namespaces.nspname as table_schema,
    tables.relname as table_name,
    triggers.tgname as trigger_name,
    triggers.tgenabled,
    lower(pg_get_triggerdef(triggers.oid, true)) as definition
  from pg_trigger as triggers
  join pg_class as tables
    on tables.oid = triggers.tgrelid
  join pg_namespace as namespaces
    on namespaces.oid = tables.relnamespace
  where not triggers.tgisinternal
)
select
  'database_webhook' as resource_type,
  expected.trigger_name as resource_name,
  expected.table_schema || '.' || expected.table_name as source,
  expected.function_name as target_function,
  expected.header_name,
  actual.trigger_name is not null as resource_exists,
  coalesce(actual.tgenabled <> 'D', false) as is_active,
  coalesce(
    position(
      '/functions/v1/' || lower(expected.function_name)
      in actual.definition
    ) > 0,
    false
  ) as endpoint_matches,
  coalesce(
    position(lower(expected.header_name) in actual.definition) > 0,
    false
  ) as header_matches,
  coalesce(
    position(expected.expected_event in actual.definition) > 0,
    false
  ) as event_matches,
  case
    when actual.trigger_name is null then 'missing'
    when actual.tgenabled = 'D' then 'inactive'
    when position(
      '/functions/v1/' || lower(expected.function_name)
      in actual.definition
    ) = 0 then 'endpoint_mismatch'
    when position(lower(expected.header_name) in actual.definition) = 0
      then 'header_mismatch'
    when position(expected.expected_event in actual.definition) = 0
      then 'event_mismatch'
    else 'ready'
  end as audit_status
from expected_webhooks as expected
left join actual_webhooks as actual
  on actual.table_schema = expected.table_schema
  and actual.table_name = expected.table_name
  and actual.trigger_name = expected.trigger_name
order by expected.trigger_name;

with expected_schedules (
  function_name,
  expected_schedule,
  accepted_header_names
) as (
  values
    (
      'dispatch-scheduled-notifications',
      '* * * * *',
      array['x-schedule-webhook-secret']::text[]
    ),
    (
      'process-ai-learning-jobs',
      '* * * * *',
      array[
        'x-ai-worker-secret',
        'x-schedule-webhook-secret'
      ]::text[]
    ),
    (
      'process-safety-moderation-alerts',
      '* * * * *',
      array[
        'x-safety-moderation-worker-secret',
        'x-schedule-webhook-secret'
      ]::text[]
    ),
    (
      'purge-disconnected-couple-archives',
      null::text,
      array[
        'x-archive-purge-webhook-secret',
        'x-schedule-webhook-secret'
      ]::text[]
    )
),
matched_schedules as (
  select
    expected.function_name,
    expected.expected_schedule,
    expected.accepted_header_names,
    jobs.jobid,
    jobs.jobname,
    jobs.schedule,
    jobs.active,
    exists (
      select 1
      from unnest(expected.accepted_header_names) as accepted(header_name)
      where position(lower(accepted.header_name) in lower(jobs.command)) > 0
    ) as header_matches
  from expected_schedules as expected
  left join cron.job as jobs
    on position(
      '/functions/v1/' || lower(expected.function_name)
      in lower(jobs.command)
    ) > 0
),
schedule_summary as (
  select
    function_name,
    expected_schedule,
    count(jobid)::integer as matching_job_count,
    coalesce(bool_or(active), false) as has_active_job,
    coalesce(bool_or(header_matches), false) as header_matches,
    coalesce(
      bool_or(
        expected_schedule is null
        or schedule = expected_schedule
      ),
      false
    ) as cadence_matches,
    array_remove(array_agg(distinct schedule), null) as configured_schedules
  from matched_schedules
  group by function_name, expected_schedule
)
select
  'cron_schedule' as resource_type,
  function_name as resource_name,
  matching_job_count,
  has_active_job,
  header_matches,
  expected_schedule,
  configured_schedules,
  case
    when matching_job_count = 0 then 'missing'
    when matching_job_count > 1 then 'duplicate'
    when not has_active_job then 'inactive'
    when not header_matches then 'header_mismatch'
    when expected_schedule is null then 'cadence_decision_required'
    when not cadence_matches then 'cadence_mismatch'
    else 'ready'
  end as audit_status
from schedule_summary
order by function_name;
