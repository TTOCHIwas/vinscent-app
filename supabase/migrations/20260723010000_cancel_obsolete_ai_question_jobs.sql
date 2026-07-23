create or replace function private.cancel_obsolete_ai_foundation_work(
  target_couple_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  cancelled_job_count integer := 0;
begin
  if target_couple_id is null
    or not private.is_ai_foundation_complete(target_couple_id)
  then
    return 0;
  end if;

  update public.ai_processing_jobs as aipj
  set
    status = 'cancelled',
    completed_at = now(),
    last_error = 'ai_foundation_completed'
  where aipj.couple_id = target_couple_id
    and aipj.job_type = 'select_curated_question'
    and aipj.status = 'pending';

  get diagnostics cancelled_job_count = row_count;

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as air
  where aiqr.couple_id = target_couple_id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and air.task = 'select_curated_question';

  return cancelled_job_count;
end;
$$;

revoke execute on function private.cancel_obsolete_ai_foundation_work(uuid)
  from public, anon, authenticated;

create or replace function private.cleanup_ai_foundation_work_after_completion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status <> 'completed' and new.status = 'completed' then
    perform private.cancel_obsolete_ai_foundation_work(new.couple_id);
  end if;

  return new;
end;
$$;

revoke execute on function
  private.cleanup_ai_foundation_work_after_completion()
  from public, anon, authenticated;

create trigger ai_focused_questions_finalize_foundation_work
  after update of status on public.ai_focused_questions
  for each row
  when (old.status is distinct from new.status)
  execute function private.cleanup_ai_foundation_work_after_completion();

create trigger daily_questions_finalize_ai_foundation_work
  after update of status on public.daily_questions
  for each row
  when (old.status is distinct from new.status)
  execute function private.cleanup_ai_foundation_work_after_completion();

do $$
declare
  target_couple record;
begin
  for target_couple in
    select distinct aipj.couple_id
    from public.ai_processing_jobs as aipj
    where aipj.job_type = 'select_curated_question'
      and aipj.status = 'pending'
  loop
    perform private.cancel_obsolete_ai_foundation_work(
      target_couple.couple_id
    );
  end loop;
end;
$$;

alter function public.claim_ai_processing_jobs(text, integer)
  rename to claim_ai_processing_jobs_without_foundation_cleanup_v10;

revoke execute on function
  public.claim_ai_processing_jobs_without_foundation_cleanup_v10(
    text,
    integer
  ) from public, anon, authenticated, service_role;

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
  target_couple record;
begin
  for target_couple in
    select distinct aipj.couple_id
    from public.ai_processing_jobs as aipj
    where aipj.job_type = 'select_curated_question'
      and aipj.status = 'pending'
  loop
    perform private.cancel_obsolete_ai_foundation_work(
      target_couple.couple_id
    );
  end loop;

  return query
    select *
    from public.claim_ai_processing_jobs_without_foundation_cleanup_v10(
      requested_worker,
      requested_limit
    );
end;
$$;

revoke execute on function public.claim_ai_processing_jobs(text, integer)
  from public, anon, authenticated;
grant execute on function public.claim_ai_processing_jobs(text, integer)
  to service_role;
