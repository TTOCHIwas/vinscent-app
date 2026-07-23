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
        coalesce(
          aipj.daily_question_id,
          aipj.focused_question_id
        ) as question_instance_id,
        aipj.job_type,
        aipj.attempts,
        aipj.lease_expires_at
    )
    select
      claimed.id,
      claimed.couple_id,
      claimed.question_instance_id,
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

create or replace function public.get_ai_processing_job_context(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_job public.ai_processing_jobs%rowtype;
  target_couple public.couples%rowtype;
  target_question public.questions%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  target_instance_id uuid;
  target_source_type text;
  completed_foundation_count integer;
  personalization_enabled boolean;
  answers_json jsonb;
  memories_json jsonb;
  memory_candidates_json jsonb;
  remaining_questions_json jsonb;
  recent_foundation_questions_json jsonb;
  recent_completed_questions_json jsonb;
  domain_progress_json jsonb;
begin
  if requested_job_id is null then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id
  for update;

  if not found
    or target_job.status <> 'processing'
    or target_job.job_type = 'rebuild_profile'
    or num_nonnulls(
      target_job.daily_question_id,
      target_job.focused_question_id
    ) <> 1
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
    )
    or (
      target_job.job_type = 'generate_personalized_question'
      and not private.is_ai_personalization_enabled(target_job.couple_id)
    )
  then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_job.couple_id
    and c.status = 'active'
    and c.user_b_id is not null;

  if not found then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  if target_job.daily_question_id is not null then
    target_source_type := 'daily';
    target_instance_id := target_job.daily_question_id;

    select q.*
    into target_question
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.id = target_job.daily_question_id
      and dq.couple_id = target_job.couple_id
      and dq.status = 'completed';
  else
    target_source_type := 'focused';
    target_instance_id := target_job.focused_question_id;

    select q.*
    into target_question
    from public.ai_focused_questions as aifq
    join public.questions as q on q.id = aifq.question_id
    where aifq.id = target_job.focused_question_id
      and aifq.couple_id = target_job.couple_id
      and aifq.status = 'completed';
  end if;

  if not found then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    perform private.raise_app_error('ai_curriculum_unavailable');
  end if;

  select count(*)::integer
  into completed_foundation_count
  from private.completed_ai_foundation_question_ids(
    target_job.couple_id,
    active_curriculum.version
  );

  personalization_enabled := private.is_ai_personalization_enabled(
    target_job.couple_id
  );

  if target_source_type = 'daily' then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'answer_id', ordered_answers.id,
          'user_id', ordered_answers.user_id,
          'text', ordered_answers.answer_text
        )
        order by ordered_answers.participant_order
      ),
      '[]'::jsonb
    )
    into answers_json
    from (
      select
        dqa.id,
        dqa.user_id,
        dqa.answer_text,
        case
          when dqa.user_id = target_couple.user_a_id then 1
          when dqa.user_id = target_couple.user_b_id then 2
          else 3
        end as participant_order
      from public.daily_question_answers as dqa
      where dqa.daily_question_id = target_instance_id
        and dqa.user_id in (
          target_couple.user_a_id,
          target_couple.user_b_id
        )
    ) as ordered_answers;
  else
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'answer_id', ordered_answers.id,
          'user_id', ordered_answers.user_id,
          'text', ordered_answers.answer_text
        )
        order by ordered_answers.participant_order
      ),
      '[]'::jsonb
    )
    into answers_json
    from (
      select
        aifqa.id,
        aifqa.user_id,
        aifqa.answer_text,
        case
          when aifqa.user_id = target_couple.user_a_id then 1
          when aifqa.user_id = target_couple.user_b_id then 2
          else 3
        end as participant_order
      from public.ai_focused_question_answers as aifqa
      where aifqa.focused_question_id = target_instance_id
        and aifqa.user_id in (
          target_couple.user_a_id,
          target_couple.user_b_id
        )
    ) as ordered_answers;
  end if;

  if jsonb_array_length(answers_json) <> 2 then
    perform private.raise_app_error('incomplete_ai_job_answers');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'memory_key', aim.memory_key,
        'scope', aim.scope,
        'subject_user_id', aim.subject_user_id,
        'kind', aim.kind,
        'learning_domain', aim.learning_domain,
        'evidence_type', aim.evidence_type,
        'statement', aim.statement,
        'confidence', aim.confidence
      )
      order by aim.updated_at, aim.id
    ),
    '[]'::jsonb
  )
  into memories_json
  from public.ai_memories as aim
  where personalization_enabled
    and aim.couple_id = target_job.couple_id
    and aim.state = 'active';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'memory_key', aim.memory_key,
        'scope', aim.scope,
        'subject_user_id', aim.subject_user_id,
        'kind', aim.kind,
        'learning_domain', aim.learning_domain,
        'evidence_type', aim.evidence_type,
        'statement', case
          when aim.state = 'rejected' then null
          else aim.statement
        end,
        'confidence', aim.confidence,
        'state', aim.state,
        'evidence_question_count', (
          select count(distinct evidence.question_instance_id)::integer
          from (
            select dqa.daily_question_id as question_instance_id
            from public.ai_memory_evidence as aime
            join public.daily_question_answers as dqa
              on dqa.id = aime.answer_id
            where aime.memory_id = aim.id

            union

            select aifqa.focused_question_id
            from public.ai_focused_memory_evidence as aifme
            join public.ai_focused_question_answers as aifqa
              on aifqa.id = aifme.answer_id
            where aifme.memory_id = aim.id
          ) as evidence
        )
      )
      order by aim.updated_at, aim.id
    ),
    '[]'::jsonb
  )
  into memory_candidates_json
  from public.ai_memories as aim
  where target_job.job_type = 'extract_memories'
    and aim.couple_id = target_job.couple_id
    and aim.state <> 'superseded';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_key', q.question_key,
        'text', q.question_text,
        'domain', q.learning_domain,
        'depth', q.question_depth,
        'prompt_angle', q.prompt_angle
      )
      order by q.curriculum_position
    ),
    '[]'::jsonb
  )
  into remaining_questions_json
  from public.questions as q
  join public.ai_question_curricula as aiqc
    on aiqc.version = q.curriculum_version
    and aiqc.status = 'active'
  where q.source = 'curated'
    and q.is_active = true
    and not private.is_ai_foundation_question_completed(
      target_job.couple_id,
      q.id
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_key', recent.question_key,
        'domain', recent.learning_domain,
        'depth', recent.question_depth,
        'prompt_angle', recent.prompt_angle
      )
      order by recent.completed_at desc, recent.instance_id
    ),
    '[]'::jsonb
  )
  into recent_foundation_questions_json
  from (
    select *
    from (
      select
        dq.id as instance_id,
        greatest(dq.updated_at, dq.created_at) as completed_at,
        q.question_key,
        q.learning_domain,
        q.question_depth,
        q.prompt_angle
      from public.daily_questions as dq
      join public.questions as q on q.id = dq.question_id
      where dq.couple_id = target_job.couple_id
        and dq.status = 'completed'
        and q.curriculum_version = active_curriculum.version
        and not (
          target_source_type = 'daily'
          and dq.id = target_instance_id
        )

      union all

      select
        aifq.id,
        greatest(aifq.updated_at, aifq.created_at),
        q.question_key,
        q.learning_domain,
        q.question_depth,
        q.prompt_angle
      from public.ai_focused_questions as aifq
      join public.questions as q on q.id = aifq.question_id
      where aifq.couple_id = target_job.couple_id
        and aifq.status = 'completed'
        and q.curriculum_version = active_curriculum.version
        and not (
          target_source_type = 'focused'
          and aifq.id = target_instance_id
        )
    ) as completed_foundation
    order by completed_at desc, instance_id
    limit 6
  ) as recent;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question', jsonb_build_object(
          'daily_question_id', recent.instance_id,
          'text', recent.question_text,
          'domain', recent.learning_domain
        ),
        'answers', case
          when recent.source_type = 'daily' then (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'answer_id', dqa.id,
                  'user_id', dqa.user_id,
                  'text', dqa.answer_text
                )
                order by case
                  when dqa.user_id = target_couple.user_a_id then 1
                  else 2
                end
              ),
              '[]'::jsonb
            )
            from public.daily_question_answers as dqa
            where dqa.daily_question_id = recent.instance_id
              and dqa.user_id in (
                target_couple.user_a_id,
                target_couple.user_b_id
              )
          )
          else (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'answer_id', aifqa.id,
                  'user_id', aifqa.user_id,
                  'text', aifqa.answer_text
                )
                order by case
                  when aifqa.user_id = target_couple.user_a_id then 1
                  else 2
                end
              ),
              '[]'::jsonb
            )
            from public.ai_focused_question_answers as aifqa
            where aifqa.focused_question_id = recent.instance_id
              and aifqa.user_id in (
                target_couple.user_a_id,
                target_couple.user_b_id
              )
          )
        end
      )
      order by recent.completed_at desc, recent.instance_id
    ),
    '[]'::jsonb
  )
  into recent_completed_questions_json
  from (
    select *
    from (
      select
        'daily'::text as source_type,
        dq.id as instance_id,
        greatest(dq.updated_at, dq.created_at) as completed_at,
        q.question_text,
        q.learning_domain
      from public.daily_questions as dq
      join public.questions as q on q.id = dq.question_id
      where personalization_enabled
        and dq.couple_id = target_job.couple_id
        and dq.status = 'completed'
        and not (
          target_source_type = 'daily'
          and dq.id = target_instance_id
        )

      union all

      select
        'focused'::text,
        aifq.id,
        greatest(aifq.updated_at, aifq.created_at),
        q.question_text,
        q.learning_domain
      from public.ai_focused_questions as aifq
      join public.questions as q on q.id = aifq.question_id
      where personalization_enabled
        and aifq.couple_id = target_job.couple_id
        and aifq.status = 'completed'
        and not (
          target_source_type = 'focused'
          and aifq.id = target_instance_id
        )
    ) as completed_questions
    order by completed_at desc, instance_id
    limit 6
  ) as recent;

  select coalesce(
    jsonb_object_agg(
      domain_rows.learning_domain,
      jsonb_build_object(
        'completed_count', domain_rows.completed_count,
        'total_count', domain_rows.total_count
      )
      order by domain_rows.learning_domain
    ),
    '{}'::jsonb
  )
  into domain_progress_json
  from (
    select
      q.learning_domain,
      count(*)::integer as total_count,
      count(*) filter (
        where private.is_ai_foundation_question_completed(
          target_job.couple_id,
          q.id
        )
      )::integer as completed_count
    from public.questions as q
    where q.curriculum_version = active_curriculum.version
      and q.is_active = true
    group by q.learning_domain
  ) as domain_rows;

  return jsonb_build_object(
    'job_id', target_job.id,
    'job_type', target_job.job_type,
    'couple_id', target_job.couple_id,
    'question', jsonb_build_object(
      'daily_question_id', target_instance_id,
      'question_id', target_question.id,
      'text', target_question.question_text,
      'domain', target_question.learning_domain,
      'depth', target_question.question_depth,
      'prompt_angle', target_question.prompt_angle
    ),
    'answers', answers_json,
    'foundation_progress', jsonb_build_object(
      'completed_count', completed_foundation_count,
      'total_count', active_curriculum.question_count,
      'personalization_enabled', personalization_enabled,
      'domain_progress', domain_progress_json
    ),
    'confirmed_memories', memories_json,
    'memory_candidates', memory_candidates_json,
    'recent_foundation_questions', recent_foundation_questions_json,
    'recent_completed_questions', recent_completed_questions_json,
    'remaining_foundation_questions', remaining_questions_json
  );
end;
$$;

revoke execute on function public.claim_ai_processing_jobs(text, integer)
  from public, anon, authenticated;
revoke execute on function public.get_ai_processing_job_context(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_ai_processing_jobs(text, integer)
  to service_role;
grant execute on function public.get_ai_processing_job_context(uuid)
  to service_role;

create or replace function public.start_ai_processing_run(
  requested_job_id uuid,
  requested_provider text,
  requested_model text,
  requested_prompt_version text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_provider text := btrim(requested_provider);
  normalized_model text := btrim(requested_model);
  normalized_prompt_version text := btrim(requested_prompt_version);
  target_job public.ai_processing_jobs%rowtype;
  target_couple public.couples%rowtype;
  existing_run_id uuid;
  answer_ids uuid[];
  created_run_id uuid;
begin
  if requested_job_id is null
    or normalized_provider is null
    or char_length(normalized_provider) not between 1 and 100
    or normalized_model is null
    or char_length(normalized_model) not between 1 and 160
    or normalized_prompt_version is null
    or char_length(normalized_prompt_version) not between 1 and 100
  then
    perform private.raise_app_error('invalid_ai_run');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_processing_run'),
    hashtext(requested_job_id::text)
  );

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id
  for update;

  if not found
    or target_job.status <> 'processing'
    or target_job.job_type = 'rebuild_profile'
    or num_nonnulls(
      target_job.daily_question_id,
      target_job.focused_question_id
    ) <> 1
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
    )
    or (
      target_job.job_type = 'generate_personalized_question'
      and not private.is_ai_personalization_enabled(target_job.couple_id)
    )
  then
    perform private.raise_app_error('invalid_ai_run_job');
  end if;

  select air.id
  into existing_run_id
  from public.ai_runs as air
  where air.job_id = target_job.id
    and air.status = 'started'
  limit 1;

  if existing_run_id is not null then
    return existing_run_id;
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_job.couple_id;

  if target_job.daily_question_id is not null then
    select array_agg(
      dqa.id
      order by case
        when dqa.user_id = target_couple.user_a_id then 1
        when dqa.user_id = target_couple.user_b_id then 2
        else 3
      end
    )
    into answer_ids
    from public.daily_question_answers as dqa
    where dqa.daily_question_id = target_job.daily_question_id
      and dqa.user_id in (
        target_couple.user_a_id,
        target_couple.user_b_id
      );
  else
    select array_agg(
      aifqa.id
      order by case
        when aifqa.user_id = target_couple.user_a_id then 1
        when aifqa.user_id = target_couple.user_b_id then 2
        else 3
      end
    )
    into answer_ids
    from public.ai_focused_question_answers as aifqa
    where aifqa.focused_question_id = target_job.focused_question_id
      and aifqa.user_id in (
        target_couple.user_a_id,
        target_couple.user_b_id
      );
  end if;

  if cardinality(answer_ids) <> 2 then
    perform private.raise_app_error('incomplete_ai_job_answers');
  end if;

  insert into public.ai_runs (
    job_id,
    couple_id,
    daily_question_id,
    focused_question_id,
    task,
    provider,
    model,
    prompt_version,
    input_answer_ids
  )
  values (
    target_job.id,
    target_job.couple_id,
    target_job.daily_question_id,
    target_job.focused_question_id,
    target_job.job_type,
    normalized_provider,
    normalized_model,
    normalized_prompt_version,
    answer_ids
  )
  returning id into created_run_id;

  return created_run_id;
end;
$$;

alter function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) rename to succeed_ai_processing_run_daily_v2;

revoke execute on function public.succeed_ai_processing_run_daily_v2(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated, service_role;

create or replace function private.succeed_ai_focused_memory_run(
  requested_run_id uuid,
  requested_output jsonb,
  requested_input_token_count integer,
  requested_output_token_count integer,
  requested_latency_ms integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
<<worker_result>>
declare
  target_run public.ai_runs%rowtype;
  target_job public.ai_processing_jobs%rowtype;
  target_couple public.couples%rowtype;
  target_question public.questions%rowtype;
  output_item jsonb;
  evidence_item jsonb;
  existing_memory public.ai_memories%rowtype;
  memory_id uuid;
  memory_key text;
  memory_scope text;
  memory_kind text;
  memory_domain text;
  memory_evidence_type text;
  memory_statement text;
  memory_confidence numeric(4, 3);
  memory_subject_text text;
  memory_subject_user_id uuid;
  sensitive_category text;
  evidence_answer_text text;
  evidence_answer_id uuid;
  memory_changed boolean;
  seen_memory_keys text[] := array[]::text[];
  seen_evidence_ids uuid[];
  completion_result boolean;
begin
  if requested_run_id is null
    or requested_output is null
    or jsonb_typeof(requested_output) <> 'object'
    or requested_input_token_count is not null
      and requested_input_token_count < 0
    or requested_output_token_count is not null
      and requested_output_token_count < 0
    or requested_latency_ms is not null
      and requested_latency_ms < 0
    or jsonb_typeof(requested_output->'memories') <> 'array'
    or jsonb_array_length(requested_output->'memories') > 12
  then
    perform private.raise_app_error('invalid_ai_run_result');
  end if;

  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id
  for update;

  if not found
    or target_run.status <> 'started'
    or target_run.job_id is null
    or target_run.task <> 'extract_memories'
    or target_run.daily_question_id is not null
    or target_run.focused_question_id is null
  then
    return false;
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = target_run.job_id
  for update;

  if not found
    or target_job.status <> 'processing'
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or target_job.couple_id <> target_run.couple_id
    or target_job.job_type <> target_run.task
    or target_job.focused_question_id <> target_run.focused_question_id
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
    )
  then
    perform private.raise_app_error('invalid_ai_run_job');
  end if;

  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_run.couple_id
    and c.status = 'active'
    and c.user_b_id is not null;

  if not found then
    perform private.raise_app_error('invalid_ai_run_job');
  end if;

  select q.*
  into target_question
  from public.ai_focused_questions as aifq
  join public.questions as q on q.id = aifq.question_id
  where aifq.id = target_run.focused_question_id
    and aifq.couple_id = target_run.couple_id
    and aifq.status = 'completed';

  if not found then
    perform private.raise_app_error('invalid_ai_run_job');
  end if;

  update public.ai_runs as air
  set
    status = 'succeeded',
    input_token_count = requested_input_token_count,
    output_token_count = requested_output_token_count,
    latency_ms = requested_latency_ms,
    safety_status = 'passed',
    error_code = null,
    completed_at = now()
  where air.id = target_run.id;

  for output_item in
    select value
    from jsonb_array_elements(requested_output->'memories')
  loop
    memory_key := btrim(output_item->>'memory_key');
    memory_scope := btrim(output_item->>'scope');
    memory_kind := btrim(output_item->>'kind');
    memory_domain := btrim(output_item->>'learning_domain');
    memory_evidence_type := btrim(output_item->>'evidence_type');
    sensitive_category := btrim(output_item->>'sensitive_category');
    memory_statement := btrim(output_item->>'statement');
    memory_subject_text := nullif(
      btrim(output_item->>'subject_user_id'),
      ''
    );

    if jsonb_typeof(output_item) <> 'object'
      or memory_key is null
      or char_length(memory_key) not between 1 and 160
      or memory_key = any(seen_memory_keys)
      or memory_scope is null
      or memory_scope not in ('personal', 'couple')
      or memory_kind is null
      or char_length(memory_kind) not between 1 and 100
      or memory_domain is null
      or memory_domain not in (
        'personal_values',
        'emotional_support',
        'communication_repair',
        'daily_life',
        'relationship_strength',
        'future_boundaries'
      )
      or memory_evidence_type is null
      or memory_evidence_type not in ('explicit', 'repeated_pattern')
      or sensitive_category is null
      or sensitive_category <> 'none'
      or memory_statement is null
      or char_length(memory_statement) not between 1 and 500
      or private.contains_blocked_ai_topic(memory_statement)
      or jsonb_typeof(output_item->'confidence') <> 'number'
      or jsonb_typeof(output_item->'evidence_answer_ids') <> 'array'
      or jsonb_array_length(
        output_item->'evidence_answer_ids'
      ) not between 1 and 2
    then
      perform private.raise_app_error('invalid_ai_memory_output');
    end if;

    memory_confidence := (output_item->>'confidence')::numeric;
    if memory_confidence < 0 or memory_confidence > 1 then
      perform private.raise_app_error('invalid_ai_memory_output');
    end if;

    if memory_scope = 'personal' then
      if memory_subject_text is null
        or memory_subject_text !~*
          '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
      then
        perform private.raise_app_error('invalid_ai_memory_output');
      end if;

      memory_subject_user_id := memory_subject_text::uuid;
      if memory_subject_user_id not in (
        target_couple.user_a_id,
        target_couple.user_b_id
      ) then
        perform private.raise_app_error('invalid_ai_memory_output');
      end if;
    else
      if memory_subject_text is not null then
        perform private.raise_app_error('invalid_ai_memory_output');
      end if;
      memory_subject_user_id := null;
    end if;

    if exists (
      select 1
      from public.ai_memories as rejected_memory
      where rejected_memory.couple_id = target_run.couple_id
        and rejected_memory.memory_key = worker_result.memory_key
        and rejected_memory.state = 'rejected'
    ) then
      continue;
    end if;

    seen_memory_keys := array_append(seen_memory_keys, memory_key);
    seen_evidence_ids := array[]::uuid[];

    for evidence_item in
      select value
      from jsonb_array_elements(output_item->'evidence_answer_ids')
    loop
      if jsonb_typeof(evidence_item) <> 'string' then
        perform private.raise_app_error('invalid_ai_memory_evidence');
      end if;

      evidence_answer_text := btrim(evidence_item #>> '{}');
      if evidence_answer_text !~*
        '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
      then
        perform private.raise_app_error('invalid_ai_memory_evidence');
      end if;

      evidence_answer_id := evidence_answer_text::uuid;
      if evidence_answer_id = any(seen_evidence_ids) then
        perform private.raise_app_error('invalid_ai_memory_evidence');
      end if;

      perform 1
      from public.ai_focused_question_answers as aifqa
      where aifqa.id = evidence_answer_id
        and aifqa.focused_question_id = target_run.focused_question_id
        and (
          memory_scope = 'couple'
          or aifqa.user_id = memory_subject_user_id
        );

      if not found then
        perform private.raise_app_error('invalid_ai_memory_evidence');
      end if;

      seen_evidence_ids := array_append(
        seen_evidence_ids,
        evidence_answer_id
      );
    end loop;

    select aim.*
    into existing_memory
    from public.ai_memories as aim
    where aim.couple_id = target_run.couple_id
      and aim.memory_key = worker_result.memory_key
    for update;

    if found then
      memory_changed :=
        existing_memory.scope is distinct from memory_scope
        or existing_memory.subject_user_id
          is distinct from memory_subject_user_id
        or existing_memory.kind is distinct from memory_kind
        or existing_memory.learning_domain is distinct from memory_domain
        or existing_memory.evidence_type
          is distinct from memory_evidence_type
        or existing_memory.statement is distinct from memory_statement;

      update public.ai_memories as aim
      set
        scope = memory_scope,
        subject_user_id = memory_subject_user_id,
        kind = memory_kind,
        learning_domain = memory_domain,
        evidence_type = memory_evidence_type,
        statement = memory_statement,
        confidence = memory_confidence,
        origin_curriculum_version = coalesce(
          aim.origin_curriculum_version,
          target_question.curriculum_version
        ),
        state = case when memory_changed then 'pending' else aim.state end,
        source_run_id = target_run.id,
        last_observed_at = now()
      where aim.id = existing_memory.id
      returning aim.id into memory_id;

      if memory_changed then
        delete from public.ai_memory_confirmations as aimc
        where aimc.memory_id = worker_result.memory_id;

        delete from public.ai_memory_evidence as aime
        where aime.memory_id = worker_result.memory_id;

        delete from public.ai_focused_memory_evidence as aifme
        where aifme.memory_id = worker_result.memory_id;
      end if;
    else
      insert into public.ai_memories (
        couple_id,
        scope,
        subject_user_id,
        memory_key,
        kind,
        learning_domain,
        evidence_type,
        origin_curriculum_version,
        statement,
        confidence,
        source_run_id,
        observed_at,
        last_observed_at
      )
      values (
        target_run.couple_id,
        memory_scope,
        memory_subject_user_id,
        memory_key,
        memory_kind,
        memory_domain,
        memory_evidence_type,
        target_question.curriculum_version,
        memory_statement,
        memory_confidence,
        target_run.id,
        now(),
        now()
      )
      returning id into memory_id;
    end if;

    foreach evidence_answer_id in array seen_evidence_ids
    loop
      insert into public.ai_focused_memory_evidence (
        memory_id,
        answer_id
      )
      values (
        worker_result.memory_id,
        evidence_answer_id
      )
      on conflict on constraint ai_focused_memory_evidence_pkey do update
      set relevance = excluded.relevance;
    end loop;
  end loop;

  completion_result := public.complete_ai_processing_job(
    target_job.id,
    'succeeded',
    null
  );

  if completion_result is not true then
    perform private.raise_app_error('ai_job_completion_failed');
  end if;

  perform private.try_activate_ai_personalization(target_run.couple_id);

  return true;
end;
$$;

create or replace function public.succeed_ai_processing_run(
  requested_run_id uuid,
  requested_output jsonb,
  requested_input_token_count integer,
  requested_output_token_count integer,
  requested_latency_ms integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_run public.ai_runs%rowtype;
  selected_question_key text;
begin
  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not found then
    return false;
  end if;

  if target_run.focused_question_id is null then
    return public.succeed_ai_processing_run_daily_v2(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );
  end if;

  if target_run.task = 'extract_memories' then
    return private.succeed_ai_focused_memory_run(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );
  end if;

  if target_run.task = 'generate_feedback' then
    perform private.raise_app_error('invalid_ai_run_task');
  end if;

  if target_run.task = 'select_curated_question' then
    selected_question_key := btrim(requested_output->>'question_key');

    if not exists (
      select 1
      from public.questions as q
      join public.ai_question_curricula as aiqc
        on aiqc.version = q.curriculum_version
        and aiqc.status = 'active'
      where q.question_key = selected_question_key
        and q.source = 'curated'
        and q.is_active = true
        and not private.is_ai_foundation_question_completed(
          target_run.couple_id,
          q.id
        )
    ) then
      perform private.raise_app_error('invalid_ai_question_output');
    end if;
  end if;

  return public.succeed_ai_processing_run_daily_v2(
    requested_run_id,
    requested_output,
    requested_input_token_count,
    requested_output_token_count,
    requested_latency_ms
  );
end;
$$;

revoke execute on function public.start_ai_processing_run(
  uuid,
  text,
  text,
  text
) from public, anon, authenticated;
revoke execute on function private.succeed_ai_focused_memory_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated;
revoke execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated;

grant execute on function public.start_ai_processing_run(
  uuid,
  text,
  text,
  text
) to service_role;
grant execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) to service_role;

create or replace function public.expand_ai_rebuild_profile_job(
  requested_job_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_job public.ai_processing_jobs%rowtype;
  completed_question record;
  latest_source_type text;
  latest_question_id uuid;
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
  next_question_job_type text;
  completion_result boolean;
begin
  if requested_job_id is null then
    perform private.raise_app_error('invalid_ai_rebuild_job');
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id
  for update;

  if not found
    or target_job.job_type <> 'rebuild_profile'
    or target_job.status <> 'processing'
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
    )
  then
    perform private.raise_app_error('invalid_ai_rebuild_job');
  end if;

  for completed_question in
    select *
    from (
      select
        'daily'::text as source_type,
        dq.id as instance_id,
        greatest(dq.updated_at, dq.created_at) as completed_at
      from public.daily_questions as dq
      where dq.couple_id = target_job.couple_id
        and dq.status = 'completed'

      union all

      select
        'focused'::text,
        aifq.id,
        greatest(aifq.updated_at, aifq.created_at)
      from public.ai_focused_questions as aifq
      where aifq.couple_id = target_job.couple_id
        and aifq.status = 'completed'
    ) as completed
    order by completed.completed_at, completed.instance_id
  loop
    latest_source_type := completed_question.source_type;
    latest_question_id := completed_question.instance_id;

    perform private.enqueue_ai_processing_job_source(
      target_job.couple_id,
      case
        when completed_question.source_type = 'daily'
          then completed_question.instance_id
        else null
      end,
      case
        when completed_question.source_type = 'focused'
          then completed_question.instance_id
        else null
      end,
      'extract_memories',
      'rebuild:' || target_job.id::text
        || ':extract:' || completed_question.source_type
        || ':' || completed_question.instance_id::text
    );

    if completed_question.source_type = 'daily' then
      perform private.enqueue_ai_processing_job_source(
        target_job.couple_id,
        completed_question.instance_id,
        null,
        'generate_feedback',
        'rebuild:' || target_job.id::text
          || ':feedback:' || completed_question.instance_id::text
      );
    end if;
  end loop;

  if latest_question_id is not null then
    select aiqc.version, aiqc.question_count
    into active_curriculum_version, foundation_question_count
    from public.ai_question_curricula as aiqc
    where aiqc.status = 'active'
    order by aiqc.version desc
    limit 1;

    if active_curriculum_version is null then
      perform private.raise_app_error('ai_curriculum_unavailable');
    end if;

    select count(*)::integer
    into completed_foundation_count
    from private.completed_ai_foundation_question_ids(
      target_job.couple_id,
      active_curriculum_version
    );

    next_question_job_type := case
      when completed_foundation_count < foundation_question_count
        then 'select_curated_question'
      else 'generate_personalized_question'
    end;

    perform private.enqueue_ai_processing_job_source(
      target_job.couple_id,
      case when latest_source_type = 'daily' then latest_question_id end,
      case when latest_source_type = 'focused' then latest_question_id end,
      next_question_job_type,
      'rebuild:' || target_job.id::text
        || ':next:' || latest_source_type
        || ':' || latest_question_id::text
    );
  end if;

  completion_result := public.complete_ai_processing_job(
    target_job.id,
    'succeeded',
    null
  );

  if completion_result is not true then
    perform private.raise_app_error('ai_job_completion_failed');
  end if;

  return true;
end;
$$;

revoke execute on function public.expand_ai_rebuild_profile_job(uuid)
  from public, anon, authenticated;
grant execute on function public.expand_ai_rebuild_profile_job(uuid)
  to service_role;
