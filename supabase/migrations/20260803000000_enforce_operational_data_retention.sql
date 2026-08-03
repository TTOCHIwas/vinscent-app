create extension if not exists pg_cron;

create index if not exists questions_generated_by_run_idx
  on public.questions (generated_by_run_id)
  where generated_by_run_id is not null;

create index if not exists ai_memories_source_run_idx
  on public.ai_memories (source_run_id);

create index if not exists ai_question_feedbacks_source_run_idx
  on public.ai_question_feedbacks (source_run_id);

create index if not exists ai_question_recommendations_source_run_idx
  on public.ai_question_recommendations (source_run_id)
  where source_run_id is not null;

create index if not exists ai_user_question_follow_ups_source_run_idx
  on public.ai_user_question_follow_ups (source_run_id)
  where source_run_id is not null;

create index if not exists ai_runs_retention_idx
  on public.ai_runs (created_at, id);

create index if not exists ai_processing_jobs_retention_idx
  on public.ai_processing_jobs (
    (coalesce(completed_at, updated_at, created_at)),
    id
  )
  where status in ('succeeded', 'failed', 'cancelled');

create index if not exists push_notification_deliveries_retention_idx
  on public.push_notification_deliveries (created_at, id);

create index if not exists push_notification_dispatches_retention_idx
  on public.push_notification_dispatches (
    (coalesce(completed_at, updated_at, created_at)),
    notification_type,
    source_id,
    receiver_user_id
  )
  where status in ('sent', 'partial_failure', 'failed', 'skipped');

create index if not exists safety_reports_retention_idx
  on public.safety_reports (reviewed_at, id)
  where status <> 'pending';

create or replace function private.ai_run_has_persistent_output(
  requested_run_id uuid
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select
    exists (
      select 1
      from public.questions as question
      where question.generated_by_run_id = requested_run_id
    )
    or exists (
      select 1
      from public.ai_memories as memory
      where memory.source_run_id = requested_run_id
    )
    or exists (
      select 1
      from public.ai_question_feedbacks as feedback
      where feedback.source_run_id = requested_run_id
    )
    or exists (
      select 1
      from public.ai_question_recommendations as recommendation
      where recommendation.source_run_id = requested_run_id
    )
    or exists (
      select 1
      from public.ai_user_question_follow_ups as follow_up
      where follow_up.source_run_id = requested_run_id
    );
$$;

revoke execute on function private.ai_run_has_persistent_output(uuid)
  from public, anon, authenticated, service_role;

create or replace function private.purge_expired_operational_records(
  requested_now timestamptz default now(),
  requested_batch_size integer default 5000
)
returns table (
  redacted_ai_run_count integer,
  deleted_ai_run_count integer,
  deleted_ai_job_count integer,
  deleted_push_delivery_count integer,
  deleted_push_dispatch_count integer,
  deleted_safety_report_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  diagnostic_cutoff timestamptz;
  safety_report_cutoff timestamptz;
  redacted_ai_run_total integer := 0;
  deleted_ai_run_total integer := 0;
  deleted_ai_job_total integer := 0;
  deleted_push_delivery_total integer := 0;
  deleted_push_dispatch_total integer := 0;
  deleted_safety_report_total integer := 0;
begin
  if requested_now is null then
    raise exception 'invalid_retention_reference_time';
  end if;

  if requested_batch_size not between 1 and 10000 then
    raise exception 'invalid_retention_batch_size';
  end if;

  if not pg_catalog.pg_try_advisory_xact_lock(
    pg_catalog.hashtext('danjjan'),
    pg_catalog.hashtext('operational_data_retention')
  ) then
    return query select 0, 0, 0, 0, 0, 0;
    return;
  end if;

  diagnostic_cutoff := requested_now - interval '90 days';
  safety_report_cutoff := requested_now - interval '1 year';

  with candidates as (
    select run.id
    from public.ai_runs as run
    where run.created_at < diagnostic_cutoff
      and private.ai_run_has_persistent_output(run.id)
      and (
        cardinality(run.input_answer_ids) > 0
        or run.input_token_count is not null
        or run.output_token_count is not null
        or run.latency_ms is not null
        or run.error_code is not null
        or run.provider_http_status is not null
        or run.provider_error_status is not null
        or run.provider_error_detail is not null
        or run.provider_retry_after_ms is not null
      )
    order by run.created_at, run.id
    limit requested_batch_size
    for update of run skip locked
  )
  update public.ai_runs as run
  set
    input_answer_ids = '{}'::uuid[],
    input_token_count = null,
    output_token_count = null,
    latency_ms = null,
    error_code = null,
    provider_http_status = null,
    provider_error_status = null,
    provider_error_detail = null,
    provider_retry_after_ms = null
  from candidates
  where run.id = candidates.id;

  get diagnostics redacted_ai_run_total = row_count;

  with candidates as (
    select run.id
    from public.ai_runs as run
    where run.created_at < diagnostic_cutoff
      and not private.ai_run_has_persistent_output(run.id)
    order by run.created_at, run.id
    limit requested_batch_size
    for update of run skip locked
  )
  delete from public.ai_runs as run
  using candidates
  where run.id = candidates.id;

  get diagnostics deleted_ai_run_total = row_count;

  with candidates as (
    select job.id
    from public.ai_processing_jobs as job
    where job.status in ('succeeded', 'failed', 'cancelled')
      and coalesce(job.completed_at, job.updated_at, job.created_at)
        < diagnostic_cutoff
    order by
      coalesce(job.completed_at, job.updated_at, job.created_at),
      job.id
    limit requested_batch_size
    for update of job skip locked
  )
  delete from public.ai_processing_jobs as job
  using candidates
  where job.id = candidates.id;

  get diagnostics deleted_ai_job_total = row_count;

  with candidates as (
    select delivery.id
    from public.push_notification_deliveries as delivery
    where delivery.created_at < diagnostic_cutoff
      and not exists (
        select 1
        from public.push_notification_dispatches as dispatch
        where dispatch.notification_type = delivery.notification_type
          and dispatch.source_id = delivery.source_id
          and dispatch.receiver_user_id is not distinct from delivery.receiver_user_id
          and (
            dispatch.status = 'processing'
            or (
              dispatch.status = 'failed'
              and dispatch.attempt_count < dispatch.max_attempts
            )
          )
      )
    order by delivery.created_at, delivery.id
    limit requested_batch_size
    for update of delivery skip locked
  )
  delete from public.push_notification_deliveries as delivery
  using candidates
  where delivery.id = candidates.id;

  get diagnostics deleted_push_delivery_total = row_count;

  with candidates as (
    select
      dispatch.notification_type,
      dispatch.source_id,
      dispatch.receiver_user_id
    from public.push_notification_dispatches as dispatch
    where coalesce(dispatch.completed_at, dispatch.updated_at, dispatch.created_at)
        < diagnostic_cutoff
      and (
        dispatch.status in ('sent', 'partial_failure', 'skipped')
        or (
          dispatch.status = 'failed'
          and dispatch.attempt_count >= dispatch.max_attempts
        )
      )
    order by
      coalesce(dispatch.completed_at, dispatch.updated_at, dispatch.created_at),
      dispatch.notification_type,
      dispatch.source_id,
      dispatch.receiver_user_id
    limit requested_batch_size
    for update of dispatch skip locked
  )
  delete from public.push_notification_dispatches as dispatch
  using candidates
  where dispatch.notification_type = candidates.notification_type
    and dispatch.source_id = candidates.source_id
    and dispatch.receiver_user_id = candidates.receiver_user_id;

  get diagnostics deleted_push_dispatch_total = row_count;

  with candidates as (
    select report.id
    from public.safety_reports as report
    where report.status <> 'pending'
      and report.reviewed_at < safety_report_cutoff
    order by report.reviewed_at, report.id
    limit requested_batch_size
    for update of report skip locked
  )
  delete from public.safety_reports as report
  using candidates
  where report.id = candidates.id;

  get diagnostics deleted_safety_report_total = row_count;

  return query
  select
    redacted_ai_run_total,
    deleted_ai_run_total,
    deleted_ai_job_total,
    deleted_push_delivery_total,
    deleted_push_dispatch_total,
    deleted_safety_report_total;
end;
$$;

revoke execute on function private.purge_expired_operational_records(
  timestamptz,
  integer
) from public, anon, authenticated, service_role;

select cron.schedule(
  'purge-expired-operational-records',
  '17 18 * * *',
  $command$
    select * from private.purge_expired_operational_records();
  $command$
);
