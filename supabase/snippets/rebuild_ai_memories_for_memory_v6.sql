-- Run only after the memory-v6 database migrations and Edge Function are deployed.
-- Replace the zero UUID with the couple whose pre-release memory data will be rebuilt.
begin;

do $$
declare
  target_couple_id constant uuid :=
    '00000000-0000-0000-0000-000000000000';
  target_prompt_version constant text := 'memory-v6';
  cancelled_question_job_count integer := 0;
  expired_recommendation_count integer := 0;
  deactivated_question_count integer := 0;
  deleted_memory_count integer := 0;
  requeued_extraction_count integer := 0;
begin
  if target_couple_id = '00000000-0000-0000-0000-000000000000'::uuid then
    raise exception 'replace target_couple_id before running this script';
  end if;

  perform pg_advisory_xact_lock(
    hashtext('rebuild_ai_memories_for_policy'),
    hashtext(target_couple_id::text)
  );

  if not exists (
    select 1
    from public.couples as c
    where c.id = target_couple_id
      and c.status = 'active'
      and c.user_b_id is not null
  ) then
    raise exception 'active couple not found: %', target_couple_id;
  end if;

  if not private.have_all_couple_members_granted_ai_consent(
    target_couple_id
  ) then
    raise exception 'both members must grant AI learning consent first';
  end if;

  if exists (
    select 1
    from public.ai_processing_jobs as aipj
    where aipj.couple_id = target_couple_id
      and aipj.status = 'processing'
  ) then
    raise exception 'AI work is currently processing; retry after it finishes';
  end if;

  if not (
    exists (
      select 1
      from public.ai_memories as aim
      join public.ai_runs as air on air.id = aim.source_run_id
      where aim.couple_id = target_couple_id
        and air.task = 'extract_memories'
        and air.prompt_version <> target_prompt_version
    )
    or exists (
      select 1
      from public.ai_processing_jobs as aipj
      cross join lateral (
        select air.prompt_version
        from public.ai_runs as air
        where air.job_id = aipj.id
          and air.task = 'extract_memories'
          and air.status = 'succeeded'
        order by
          air.completed_at desc nulls last,
          air.created_at desc,
          air.id desc
        limit 1
      ) as latest_run
      where aipj.couple_id = target_couple_id
        and aipj.job_type = 'extract_memories'
        and latest_run.prompt_version <> target_prompt_version
    )
  ) then
    raise notice 'No legacy AI memory data found for couple %', target_couple_id;
    return;
  end if;

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as air
  where aiqr.couple_id = target_couple_id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and air.task = 'generate_personalized_question';

  get diagnostics expired_recommendation_count = row_count;

  update public.questions as q
  set is_active = false
  from public.ai_runs as air
  where q.personalized_for_couple_id = target_couple_id
    and q.generated_by_run_id = air.id
    and air.task = 'generate_personalized_question'
    and q.is_active = true;

  get diagnostics deactivated_question_count = row_count;

  update public.ai_processing_jobs as aipj
  set
    status = 'cancelled',
    completed_at = now(),
    claimed_at = null,
    claimed_by = null,
    lease_expires_at = null,
    last_error = 'ai_memory_policy_rebuild'
  where aipj.couple_id = target_couple_id
    and aipj.job_type = 'generate_personalized_question'
    and aipj.status = 'pending';

  get diagnostics cancelled_question_job_count = row_count;

  delete from public.ai_personalization_states as aips
  where aips.couple_id = target_couple_id;

  delete from public.ai_memories as aim
  where aim.couple_id = target_couple_id;

  get diagnostics deleted_memory_count = row_count;

  update public.ai_processing_jobs as aipj
  set
    status = 'pending',
    attempts = 0,
    max_attempts = greatest(aipj.max_attempts, 5),
    available_at = now(),
    claimed_at = null,
    claimed_by = null,
    lease_expires_at = null,
    completed_at = null,
    last_error = null
  where aipj.couple_id = target_couple_id
    and aipj.job_type = 'extract_memories';

  get diagnostics requeued_extraction_count = row_count;

  if requeued_extraction_count = 0 then
    raise exception 'no memory extraction jobs found for couple %', target_couple_id;
  end if;

  raise notice
    'Memory rebuild queued: extractions=%, deleted_memories=%, cancelled_questions=%, expired_recommendations=%, deactivated_questions=%',
    requeued_extraction_count,
    deleted_memory_count,
    cancelled_question_job_count,
    expired_recommendation_count,
    deactivated_question_count;
end;
$$;

commit;
