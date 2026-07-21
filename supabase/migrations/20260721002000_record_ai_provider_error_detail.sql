alter table public.ai_runs
  add column provider_error_detail text;

alter table public.ai_runs
  add constraint ai_runs_provider_error_detail_check
    check (
      provider_error_detail is null
      or char_length(provider_error_detail) between 1 and 500
    );

create function public.fail_ai_processing_run_with_diagnostics_v2(
  requested_run_id uuid,
  requested_error_code text,
  requested_safety_status text,
  requested_retryable boolean,
  requested_input_token_count integer,
  requested_output_token_count integer,
  requested_latency_ms integer,
  requested_provider_http_status integer,
  requested_provider_error_status text,
  requested_provider_error_detail text,
  requested_retry_after_ms integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_error_code text := btrim(requested_error_code);
  normalized_safety_status text := btrim(requested_safety_status);
  normalized_provider_error_status text := nullif(
    left(btrim(requested_provider_error_status), 100),
    ''
  );
  normalized_provider_error_detail text := nullif(
    left(
      regexp_replace(
        btrim(requested_provider_error_detail),
        '[[:space:]]+',
        ' ',
        'g'
      ),
      500
    ),
    ''
  );
  target_run public.ai_runs%rowtype;
  target_job public.ai_processing_jobs%rowtype;
  base_retry_ms integer;
  jitter_ms integer;
  retry_delay_ms integer;
begin
  if requested_run_id is null
    or normalized_error_code is null
    or char_length(normalized_error_code) not between 1 and 160
    or normalized_safety_status is null
    or normalized_safety_status not in ('flagged', 'error')
    or requested_retryable is null
    or requested_input_token_count is not null
      and requested_input_token_count < 0
    or requested_output_token_count is not null
      and requested_output_token_count < 0
    or requested_latency_ms is not null
      and requested_latency_ms < 0
    or requested_provider_http_status is not null
      and requested_provider_http_status not between 100 and 599
    or normalized_provider_error_status is not null
      and normalized_provider_error_status !~ '^[A-Z][A-Z0-9_]{0,99}$'
    or requested_retry_after_ms is not null
      and requested_retry_after_ms not between 0 and 86400000
  then
    perform private.raise_app_error('invalid_ai_run_failure');
  end if;

  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id
  for update;

  if not found or target_run.status <> 'started' or target_run.job_id is null then
    return false;
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = target_run.job_id
  for update;

  update public.ai_runs as air
  set
    status = case
      when target_job.status = 'processing' then 'failed'
      else 'cancelled'
    end,
    input_token_count = requested_input_token_count,
    output_token_count = requested_output_token_count,
    latency_ms = requested_latency_ms,
    safety_status = normalized_safety_status,
    error_code = normalized_error_code,
    provider_http_status = requested_provider_http_status,
    provider_error_status = normalized_provider_error_status,
    provider_error_detail = normalized_provider_error_detail,
    provider_retry_after_ms = requested_retry_after_ms,
    completed_at = now()
  where air.id = target_run.id;

  if target_job.id is null or target_job.status <> 'processing' then
    return false;
  end if;

  if requested_retryable and target_job.attempts < target_job.max_attempts then
    base_retry_ms := least(
      900000,
      (
        60000
        * power(2::numeric, greatest(target_job.attempts - 1, 0))
      )::integer
    );
    jitter_ms := floor(random() * 30001)::integer;
    retry_delay_ms := greatest(
      base_retry_ms,
      coalesce(requested_retry_after_ms, 0)
    ) + jitter_ms;

    update public.ai_processing_jobs as aipj
    set
      status = 'pending',
      available_at = now() + make_interval(
        secs => retry_delay_ms / 1000.0
      ),
      claimed_at = null,
      claimed_by = null,
      lease_expires_at = null,
      completed_at = null,
      last_error = normalized_error_code
    where aipj.id = target_job.id;

    return true;
  end if;

  update public.ai_processing_jobs as aipj
  set
    status = 'failed',
    completed_at = now(),
    lease_expires_at = null,
    last_error = normalized_error_code
  where aipj.id = target_job.id
    and aipj.status = 'processing';

  return found;
end;
$$;

revoke execute on function public.fail_ai_processing_run_with_diagnostics_v2(
  uuid,
  text,
  text,
  boolean,
  integer,
  integer,
  integer,
  integer,
  text,
  text,
  integer
) from public, anon, authenticated;

grant execute on function public.fail_ai_processing_run_with_diagnostics_v2(
  uuid,
  text,
  text,
  boolean,
  integer,
  integer,
  integer,
  integer,
  text,
  text,
  integer
) to service_role;
