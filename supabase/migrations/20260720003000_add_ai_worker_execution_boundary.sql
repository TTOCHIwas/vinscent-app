create unique index ai_runs_one_started_per_job_idx
  on public.ai_runs (job_id)
  where job_id is not null and status = 'started';

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
  target_daily_question public.daily_questions%rowtype;
  target_question public.questions%rowtype;
  answers_json jsonb;
  memories_json jsonb;
  remaining_questions_json jsonb;
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
    or target_job.daily_question_id is null
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
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

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.id = target_job.daily_question_id
    and dq.couple_id = target_job.couple_id
    and dq.status = 'completed';

  if not found then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

  select q.*
  into target_question
  from public.questions as q
  where q.id = target_daily_question.question_id;

  if not found then
    perform private.raise_app_error('invalid_ai_job_context');
  end if;

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
    where dqa.daily_question_id = target_daily_question.id
      and dqa.user_id in (
        target_couple.user_a_id,
        target_couple.user_b_id
      )
  ) as ordered_answers;

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
        'statement', aim.statement,
        'confidence', aim.confidence
      )
      order by aim.updated_at, aim.id
    ),
    '[]'::jsonb
  )
  into memories_json
  from public.ai_memories as aim
  where aim.couple_id = target_job.couple_id
    and aim.state = 'active';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_key', remaining.question_key,
        'text', remaining.question_text,
        'domain', remaining.learning_domain
      )
      order by remaining.curriculum_position
    ),
    '[]'::jsonb
  )
  into remaining_questions_json
  from (
    select
      q.id,
      q.question_key,
      q.question_text,
      q.learning_domain,
      q.curriculum_position
    from public.questions as q
    join public.ai_question_curricula as aiqc
      on aiqc.version = q.curriculum_version
      and aiqc.status = 'active'
    where q.source = 'curated'
      and q.is_active = true
      and not exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_job.couple_id
          and used_dq.question_id = q.id
      )
  ) as remaining;

  return jsonb_build_object(
    'job_id', target_job.id,
    'job_type', target_job.job_type,
    'couple_id', target_job.couple_id,
    'question', jsonb_build_object(
      'daily_question_id', target_daily_question.id,
      'question_id', target_question.id,
      'text', target_question.question_text,
      'domain', target_question.learning_domain
    ),
    'answers', answers_json,
    'confirmed_memories', memories_json,
    'remaining_foundation_questions', remaining_questions_json
  );
end;
$$;

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
    or target_job.daily_question_id is null
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
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

  if cardinality(answer_ids) <> 2 then
    perform private.raise_app_error('incomplete_ai_job_answers');
  end if;

  insert into public.ai_runs (
    job_id,
    couple_id,
    daily_question_id,
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
<<worker_result>>
declare
  target_run public.ai_runs%rowtype;
  target_job public.ai_processing_jobs%rowtype;
  target_couple public.couples%rowtype;
  output_item jsonb;
  evidence_item jsonb;
  existing_memory public.ai_memories%rowtype;
  memory_id uuid;
  memory_key text;
  memory_scope text;
  memory_kind text;
  memory_statement text;
  memory_confidence numeric(4, 3);
  memory_subject_text text;
  memory_subject_user_id uuid;
  evidence_answer_text text;
  evidence_answer_id uuid;
  memory_changed boolean;
  seen_memory_keys text[] := array[]::text[];
  seen_evidence_ids uuid[];
  feedback_text text;
  question_key text;
  rationale text;
  question_text text;
  question_category text;
  question_mood text;
  target_question_id uuid;
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
  then
    perform private.raise_app_error('invalid_ai_run_result');
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

  if not found
    or target_job.status <> 'processing'
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or target_job.couple_id <> target_run.couple_id
    or target_job.job_type <> target_run.task
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

  if target_run.task = 'extract_memories' then
    if jsonb_typeof(requested_output->'memories') <> 'array'
      or jsonb_array_length(requested_output->'memories') > 12
    then
      perform private.raise_app_error('invalid_ai_memory_output');
    end if;

    for output_item in
      select value
      from jsonb_array_elements(requested_output->'memories')
    loop
      memory_key := btrim(output_item->>'memory_key');
      memory_scope := btrim(output_item->>'scope');
      memory_kind := btrim(output_item->>'kind');
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
        or memory_statement is null
        or char_length(memory_statement) not between 1 and 500
        or jsonb_typeof(output_item->'confidence') <> 'number'
        or jsonb_typeof(output_item->'evidence_answer_ids') <> 'array'
        or jsonb_array_length(output_item->'evidence_answer_ids') not between 1 and 2
      then
        perform private.raise_app_error('invalid_ai_memory_output');
      end if;

      memory_confidence := (output_item->>'confidence')::numeric;
      if memory_confidence < 0 or memory_confidence > 1 then
        perform private.raise_app_error('invalid_ai_memory_output');
      end if;

      if memory_scope = 'personal' then
        if memory_subject_text is null
          or memory_subject_text !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
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
        if evidence_answer_text !~* '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
        then
          perform private.raise_app_error('invalid_ai_memory_evidence');
        end if;

        evidence_answer_id := evidence_answer_text::uuid;
        if evidence_answer_id = any(seen_evidence_ids) then
          perform private.raise_app_error('invalid_ai_memory_evidence');
        end if;

        perform 1
        from public.daily_question_answers as dqa
        where dqa.id = evidence_answer_id
          and dqa.daily_question_id = target_run.daily_question_id
          and (
            memory_scope = 'couple'
            or dqa.user_id = memory_subject_user_id
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
        memory_changed := existing_memory.scope is distinct from memory_scope
          or existing_memory.subject_user_id is distinct from memory_subject_user_id
          or existing_memory.kind is distinct from memory_kind
          or existing_memory.statement is distinct from memory_statement;

        update public.ai_memories as aim
        set
          scope = memory_scope,
          subject_user_id = memory_subject_user_id,
          kind = memory_kind,
          statement = memory_statement,
          confidence = memory_confidence,
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
        end if;
      else
        insert into public.ai_memories (
          couple_id,
          scope,
          subject_user_id,
          memory_key,
          kind,
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
        insert into public.ai_memory_evidence (
          memory_id,
          answer_id
        )
        values (
          worker_result.memory_id,
          evidence_answer_id
        )
        on conflict on constraint ai_memory_evidence_pkey do update
        set relevance = excluded.relevance;
      end loop;
    end loop;
  elsif target_run.task = 'generate_feedback' then
    feedback_text := btrim(requested_output->>'feedback_text');
    if feedback_text is null
      or char_length(feedback_text) not between 1 and 500
    then
      perform private.raise_app_error('invalid_ai_feedback_output');
    end if;

    insert into public.ai_question_feedbacks (
      daily_question_id,
      couple_id,
      feedback_text,
      state,
      safety_status,
      source_run_id,
      published_at
    )
    values (
      target_run.daily_question_id,
      target_run.couple_id,
      feedback_text,
      'published',
      'passed',
      target_run.id,
      now()
    )
    on conflict (daily_question_id) do update
    set
      feedback_text = excluded.feedback_text,
      state = excluded.state,
      safety_status = excluded.safety_status,
      source_run_id = excluded.source_run_id,
      published_at = excluded.published_at;
  elsif target_run.task = 'select_curated_question' then
    question_key := btrim(requested_output->>'question_key');
    rationale := btrim(requested_output->>'rationale');
    if question_key is null
      or char_length(question_key) not between 1 and 120
      or rationale is null
      or char_length(rationale) not between 1 and 500
    then
      perform private.raise_app_error('invalid_ai_question_output');
    end if;

    select q.id
    into target_question_id
    from public.questions as q
    join public.ai_question_curricula as aiqc
      on aiqc.version = q.curriculum_version
      and aiqc.status = 'active'
    where q.question_key = worker_result.question_key
      and q.source = 'curated'
      and q.is_active = true
      and not exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_run.couple_id
          and used_dq.question_id = q.id
      );

    if target_question_id is null then
      perform private.raise_app_error('invalid_ai_question_output');
    end if;

    perform public.record_ai_question_recommendation(
      target_run.id,
      target_run.couple_id,
      target_question_id,
      rationale
    );
  elsif target_run.task = 'generate_personalized_question' then
    question_key := btrim(requested_output->>'question_key');
    question_text := btrim(requested_output->>'question_text');
    question_category := btrim(requested_output->>'category');
    question_mood := nullif(btrim(requested_output->>'mood'), '');
    rationale := btrim(requested_output->>'rationale');

    if question_key is null
      or char_length(question_key) not between 1 and 120
      or question_text is null
      or char_length(question_text) not between 1 and 300
      or question_category is null
      or char_length(question_category) not between 1 and 100
      or question_mood is not null
        and char_length(question_mood) not between 1 and 100
      or rationale is null
      or char_length(rationale) not between 1 and 500
    then
      perform private.raise_app_error('invalid_ai_question_output');
    end if;

    target_question_id := public.create_ai_question_candidate(
      target_run.id,
      question_key,
      question_text,
      question_category,
      question_mood
    );

    perform public.record_ai_question_recommendation(
      target_run.id,
      target_run.couple_id,
      target_question_id,
      rationale
    );
  else
    perform private.raise_app_error('invalid_ai_run_task');
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

create or replace function public.fail_ai_processing_run(
  requested_run_id uuid,
  requested_error_code text,
  requested_safety_status text,
  requested_retryable boolean,
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
  normalized_error_code text := btrim(requested_error_code);
  normalized_safety_status text := btrim(requested_safety_status);
  target_run public.ai_runs%rowtype;
  target_job public.ai_processing_jobs%rowtype;
  completion_result boolean;
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
    completed_at = now()
  where air.id = target_run.id;

  if target_job.id is null or target_job.status <> 'processing' then
    return false;
  end if;

  if requested_retryable then
    completion_result := public.complete_ai_processing_job(
      target_job.id,
      'failed',
      normalized_error_code
    );
  else
    update public.ai_processing_jobs as aipj
    set
      status = 'failed',
      completed_at = now(),
      lease_expires_at = null,
      last_error = normalized_error_code
    where aipj.id = target_job.id
      and aipj.status = 'processing';

    completion_result := found;
  end if;

  return completion_result;
end;
$$;

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
  latest_completed_question_id uuid;
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
    select dq.id
    from public.daily_questions as dq
    where dq.couple_id = target_job.couple_id
      and dq.status = 'completed'
    order by dq.assigned_date, dq.created_at, dq.id
  loop
    latest_completed_question_id := completed_question.id;

    perform private.enqueue_ai_processing_job(
      target_job.couple_id,
      completed_question.id,
      'extract_memories',
      'rebuild:' || target_job.id::text
        || ':extract:' || completed_question.id::text
    );

    perform private.enqueue_ai_processing_job(
      target_job.couple_id,
      completed_question.id,
      'generate_feedback',
      'rebuild:' || target_job.id::text
        || ':feedback:' || completed_question.id::text
    );
  end loop;

  if latest_completed_question_id is not null then
    select aiqc.version, aiqc.question_count
    into active_curriculum_version, foundation_question_count
    from public.ai_question_curricula as aiqc
    where aiqc.status = 'active'
    order by aiqc.version desc
    limit 1;

    if active_curriculum_version is null then
      perform private.raise_app_error('ai_curriculum_unavailable');
    end if;

    select count(distinct dq.question_id)::integer
    into completed_foundation_count
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = target_job.couple_id
      and dq.status = 'completed'
      and q.curriculum_version = active_curriculum_version;

    next_question_job_type := case
      when completed_foundation_count < foundation_question_count
        then 'select_curated_question'
      else 'generate_personalized_question'
    end;

    perform private.enqueue_ai_processing_job(
      target_job.couple_id,
      latest_completed_question_id,
      next_question_job_type,
      'rebuild:' || target_job.id::text
        || ':next:' || latest_completed_question_id::text
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

revoke execute on function public.get_ai_processing_job_context(uuid)
  from public, anon, authenticated;
revoke execute on function public.start_ai_processing_run(
  uuid,
  text,
  text,
  text
) from public, anon, authenticated;
revoke execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated;
revoke execute on function public.fail_ai_processing_run(
  uuid,
  text,
  text,
  boolean,
  integer,
  integer,
  integer
) from public, anon, authenticated;
revoke execute on function public.expand_ai_rebuild_profile_job(uuid)
  from public, anon, authenticated;

grant execute on function public.get_ai_processing_job_context(uuid)
  to service_role;
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
grant execute on function public.fail_ai_processing_run(
  uuid,
  text,
  text,
  boolean,
  integer,
  integer,
  integer
) to service_role;
grant execute on function public.expand_ai_rebuild_profile_job(uuid)
  to service_role;
