create or replace function private.ai_processing_job_priority(
  requested_job_type text
)
returns smallint
language sql
immutable
strict
set search_path = ''
as $$
  select (
    case requested_job_type
      when 'rebuild_profile' then 0
      when 'generate_feedback' then 10
      when 'select_curated_question' then 20
      when 'generate_personalized_question' then 20
      when 'extract_memories' then 30
      else 100
    end
  )::smallint;
$$;

revoke execute on function private.ai_processing_job_priority(text)
  from public, anon, authenticated;
grant execute on function private.ai_processing_job_priority(text)
  to service_role;

drop index if exists public.ai_processing_jobs_claim_idx;

create index ai_processing_jobs_claim_idx
  on public.ai_processing_jobs (
    status,
    private.ai_processing_job_priority(job_type),
    available_at,
    created_at,
    id
  )
  where status in ('pending', 'processing');

create or replace function public.claim_ai_processing_jobs(
  requested_worker text,
  requested_limit integer
)
returns table (
  job_id uuid,
  job_couple_id uuid,
  job_daily_question_id uuid,
  job_type text,
  job_attempt integer,
  job_lease_expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_worker text := btrim(requested_worker);
  claim_limit integer := least(greatest(coalesce(requested_limit, 1), 1), 20);
begin
  if normalized_worker is null
    or char_length(normalized_worker) not between 1 and 120
  then
    perform private.raise_app_error('invalid_ai_worker');
  end if;

  update public.ai_processing_jobs as aipj
  set
    status = case
      when aipj.attempts >= aipj.max_attempts then 'failed'
      else 'pending'
    end,
    available_at = case
      when aipj.attempts >= aipj.max_attempts then aipj.available_at
      else now()
    end,
    claimed_at = null,
    claimed_by = null,
    lease_expires_at = null,
    completed_at = case
      when aipj.attempts >= aipj.max_attempts then now()
      else null
    end,
    last_error = 'worker_lease_expired'
  where aipj.status = 'processing'
    and aipj.lease_expires_at < now();

  return query
    with candidates as materialized (
      select
        aipj.id,
        private.ai_processing_job_priority(aipj.job_type) as job_priority,
        aipj.available_at as candidate_available_at,
        aipj.created_at as candidate_created_at
      from public.ai_processing_jobs as aipj
      where aipj.status = 'pending'
        and aipj.available_at <= now()
        and aipj.attempts < aipj.max_attempts
        and private.have_all_couple_members_granted_ai_consent(
          aipj.couple_id
        )
        and (
          aipj.job_type <> 'generate_personalized_question'
          or private.is_ai_personalization_enabled(aipj.couple_id)
        )
      order by
        private.ai_processing_job_priority(aipj.job_type),
        aipj.available_at,
        aipj.created_at,
        aipj.id
      for update skip locked
      limit claim_limit
    ),
    claimed as (
      update public.ai_processing_jobs as aipj
      set
        status = 'processing',
        attempts = aipj.attempts + 1,
        claimed_at = now(),
        claimed_by = normalized_worker,
        lease_expires_at = now() + interval '5 minutes',
        completed_at = null,
        last_error = null
      from candidates
      where aipj.id = candidates.id
      returning
        aipj.id,
        aipj.couple_id,
        aipj.daily_question_id,
        aipj.job_type,
        aipj.attempts,
        aipj.lease_expires_at
    )
    select
      claimed.id,
      claimed.couple_id,
      claimed.daily_question_id,
      claimed.job_type,
      claimed.attempts,
      claimed.lease_expires_at
    from claimed
    join candidates on candidates.id = claimed.id
    order by
      candidates.job_priority,
      candidates.candidate_available_at,
      candidates.candidate_created_at,
      candidates.id;
end;
$$;
