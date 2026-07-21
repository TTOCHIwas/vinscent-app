alter table public.questions
  add column question_depth text;

update public.questions
set question_depth = case curriculum_position
  when 1 then 'light'
  when 2 then 'exploratory'
  when 3 then 'light'
  when 4 then 'deep'
  when 5 then 'exploratory'
  when 6 then 'light'
  when 7 then 'light'
  when 8 then 'exploratory'
  when 9 then 'exploratory'
  when 10 then 'deep'
  when 11 then 'exploratory'
  when 12 then 'deep'
  when 13 then 'light'
  when 14 then 'exploratory'
  when 15 then 'deep'
  when 16 then 'light'
  when 17 then 'exploratory'
  when 18 then 'light'
  when 19 then 'deep'
  when 20 then 'deep'
  when 21 then 'light'
  when 22 then 'deep'
  when 23 then 'exploratory'
  when 24 then 'deep'
end
where curriculum_version = 1;

alter table public.questions
  add constraint questions_question_depth_check
    check (
      (curriculum_version is null and question_depth is null)
      or (
        curriculum_version is not null
        and question_depth in ('light', 'exploratory', 'deep')
      )
    );

alter table public.ai_memories
  add column learning_domain text not null default 'daily_life',
  add column evidence_type text not null default 'explicit',
  add column origin_curriculum_version integer
    references public.ai_question_curricula(version) on delete restrict,
  add constraint ai_memories_learning_domain_check
    check (
      learning_domain in (
        'personal_values',
        'emotional_support',
        'communication_repair',
        'daily_life',
        'relationship_strength',
        'future_boundaries'
      )
    ),
  add constraint ai_memories_evidence_type_check
    check (evidence_type in ('explicit', 'repeated_pattern'));

update public.ai_question_feedbacks
set feedback_text = left(btrim(feedback_text), 80)
where char_length(btrim(feedback_text)) > 80;

alter table public.ai_question_feedbacks
  drop constraint ai_question_feedbacks_text_check,
  add constraint ai_question_feedbacks_text_check
    check (char_length(btrim(feedback_text)) between 1 and 80);

update public.ai_memories as aim
set
  learning_domain = coalesce(q.learning_domain, aim.learning_domain),
  origin_curriculum_version = q.curriculum_version
from public.ai_runs as air
left join public.daily_questions as dq
  on dq.id = air.daily_question_id
left join public.questions as q
  on q.id = dq.question_id
where air.id = aim.source_run_id;

create table public.ai_personalization_states (
  couple_id uuid not null references public.couples(id) on delete cascade,
  curriculum_version integer not null
    references public.ai_question_curricula(version) on delete restrict,
  activated_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (couple_id, curriculum_version)
);

alter table public.ai_personalization_states enable row level security;

create trigger ai_personalization_states_set_updated_at
  before update on public.ai_personalization_states
  for each row
  execute function public.set_updated_at();

create or replace function private.is_ai_memory_review_eligible(
  target_memory_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.ai_memories as aim
    where aim.id = target_memory_id
      and exists (
        select 1
        from public.ai_memory_evidence as aime
        where aime.memory_id = aim.id
      )
      and (
        aim.evidence_type = 'explicit'
        or (
          aim.evidence_type = 'repeated_pattern'
          and (
            select count(distinct dqa.daily_question_id)
            from public.ai_memory_evidence as aime
            join public.daily_question_answers as dqa
              on dqa.id = aime.answer_id
            where aime.memory_id = aim.id
          ) >= 2
        )
      )
  );
$$;

create or replace function private.is_ai_foundation_processing_complete(
  target_couple_id uuid,
  target_curriculum_version integer
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = target_couple_id
      and dq.status = 'completed'
      and q.curriculum_version = target_curriculum_version
      and not exists (
        select 1
        from public.ai_processing_jobs as aipj
        where aipj.couple_id = target_couple_id
          and aipj.daily_question_id = dq.id
          and aipj.job_type = 'extract_memories'
          and aipj.status = 'succeeded'
      )
  );
$$;

create or replace function private.is_ai_personalization_enabled(
  target_couple_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.have_all_couple_members_granted_ai_consent(target_couple_id)
    and exists (
      select 1
      from public.ai_personalization_states as aips
      join public.ai_question_curricula as aiqc
        on aiqc.version = aips.curriculum_version
        and aiqc.status = 'active'
      where aips.couple_id = target_couple_id
        and aips.activated_at is not null
    );
$$;

create or replace function private.try_activate_ai_personalization(
  target_couple_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_curriculum public.ai_question_curricula%rowtype;
  completed_foundation_count integer;
begin
  if target_couple_id is null
    or not private.have_all_couple_members_granted_ai_consent(target_couple_id)
  then
    return false;
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    return false;
  end if;

  if exists (
    select 1
    from public.ai_personalization_states as aips
    where aips.couple_id = target_couple_id
      and aips.curriculum_version = active_curriculum.version
  ) then
    return true;
  end if;

  select count(distinct dq.question_id)::integer
  into completed_foundation_count
  from public.daily_questions as dq
  join public.questions as q on q.id = dq.question_id
  where dq.couple_id = target_couple_id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum.version;

  if completed_foundation_count < active_curriculum.question_count
    or not private.is_ai_foundation_processing_complete(
      target_couple_id,
      active_curriculum.version
    )
    or exists (
      select 1
      from public.ai_memories as aim
      where aim.couple_id = target_couple_id
        and aim.origin_curriculum_version = active_curriculum.version
        and aim.state = 'pending'
        and private.is_ai_memory_review_eligible(aim.id)
    )
  then
    return false;
  end if;

  insert into public.ai_personalization_states (
    couple_id,
    curriculum_version,
    activated_at
  )
  values (
    target_couple_id,
    active_curriculum.version,
    now()
  )
  on conflict (couple_id, curriculum_version) do nothing;

  return true;
end;
$$;

revoke execute on function private.is_ai_memory_review_eligible(uuid)
  from public, anon, authenticated;
revoke execute on function private.is_ai_foundation_processing_complete(uuid, integer)
  from public, anon, authenticated;
revoke execute on function private.is_ai_personalization_enabled(uuid)
  from public, anon, authenticated;
revoke execute on function private.try_activate_ai_personalization(uuid)
  from public, anon, authenticated;

create or replace function public.get_ai_learning_progress()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  completed_count integer;
  learning_stage text;
  domain_progress jsonb;
  my_consent_status text;
  partner_consent_status text;
  partner_user_id uuid;
  all_members_consented boolean;
  foundation_complete boolean;
  memory_processing_complete boolean;
  memory_processing_failed boolean;
  personalization_enabled boolean;
  my_pending_review_count integer;
  partner_pending_review_count integer;
  personalization_status text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    perform private.raise_app_error('ai_curriculum_unavailable');
  end if;

  select count(distinct dq.question_id)::integer
  into completed_count
  from public.daily_questions as dq
  join public.questions as q on q.id = dq.question_id
  where dq.couple_id = active_couple.id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum.version;

  learning_stage := case
    when completed_count < ceil(active_curriculum.question_count / 3.0)
      then 'collecting'
    when completed_count < ceil(active_curriculum.question_count * 2 / 3.0)
      then 'exploring'
    when completed_count < active_curriculum.question_count
      then 'refining'
    else 'ready'
  end;

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
  into domain_progress
  from (
    select
      q.learning_domain,
      count(*)::integer as total_count,
      count(*) filter (
        where exists (
          select 1
          from public.daily_questions as dq
          where dq.couple_id = active_couple.id
            and dq.question_id = q.id
            and dq.status = 'completed'
        )
      )::integer as completed_count
    from public.questions as q
    where q.curriculum_version = active_curriculum.version
      and q.is_active = true
    group by q.learning_domain
  ) as domain_rows;

  partner_user_id := case
    when active_couple.user_a_id = current_user_id
      then active_couple.user_b_id
    else active_couple.user_a_id
  end;

  select coalesce(auc.status, 'revoked')
  into my_consent_status
  from (select 1) as singleton
  left join public.ai_user_consents as auc
    on auc.couple_id = active_couple.id
    and auc.user_id = current_user_id;

  select coalesce(auc.status, 'revoked')
  into partner_consent_status
  from (select 1) as singleton
  left join public.ai_user_consents as auc
    on auc.couple_id = active_couple.id
    and auc.user_id = partner_user_id;

  all_members_consented := private.have_all_couple_members_granted_ai_consent(
    active_couple.id
  );
  foundation_complete := completed_count >= active_curriculum.question_count;
  memory_processing_complete := foundation_complete
    and private.is_ai_foundation_processing_complete(
      active_couple.id,
      active_curriculum.version
    );

  select foundation_complete and exists (
    select 1
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = active_couple.id
      and dq.status = 'completed'
      and q.curriculum_version = active_curriculum.version
      and not exists (
        select 1
        from public.ai_processing_jobs as succeeded_job
        where succeeded_job.couple_id = active_couple.id
          and succeeded_job.daily_question_id = dq.id
          and succeeded_job.job_type = 'extract_memories'
          and succeeded_job.status = 'succeeded'
      )
      and exists (
        select 1
        from public.ai_processing_jobs as failed_job
        where failed_job.couple_id = active_couple.id
          and failed_job.daily_question_id = dq.id
          and failed_job.job_type = 'extract_memories'
          and failed_job.status in ('failed', 'cancelled')
      )
      and not exists (
        select 1
        from public.ai_processing_jobs as running_job
        where running_job.couple_id = active_couple.id
          and running_job.daily_question_id = dq.id
          and running_job.job_type = 'extract_memories'
          and running_job.status in ('pending', 'processing')
      )
  )
  into memory_processing_failed;

  if memory_processing_complete and all_members_consented then
    perform private.try_activate_ai_personalization(active_couple.id);
  end if;

  personalization_enabled := private.is_ai_personalization_enabled(
    active_couple.id
  );

  select count(*)::integer
  into my_pending_review_count
  from public.ai_memories as aim
  where aim.couple_id = active_couple.id
    and aim.origin_curriculum_version = active_curriculum.version
    and aim.state = 'pending'
    and private.is_ai_memory_review_eligible(aim.id)
    and (
      (aim.scope = 'personal' and aim.subject_user_id = current_user_id)
      or (
        aim.scope = 'couple'
        and not exists (
          select 1
          from public.ai_memory_confirmations as aimc
          where aimc.memory_id = aim.id
            and aimc.user_id = current_user_id
        )
      )
    );

  select count(*)::integer
  into partner_pending_review_count
  from public.ai_memories as aim
  where aim.couple_id = active_couple.id
    and aim.origin_curriculum_version = active_curriculum.version
    and aim.state = 'pending'
    and private.is_ai_memory_review_eligible(aim.id)
    and (
      (aim.scope = 'personal' and aim.subject_user_id = partner_user_id)
      or (
        aim.scope = 'couple'
        and not exists (
          select 1
          from public.ai_memory_confirmations as aimc
          where aimc.memory_id = aim.id
            and aimc.user_id = partner_user_id
        )
      )
    );

  personalization_status := case
    when not foundation_complete then 'collecting'
    when not memory_processing_complete and memory_processing_failed
      then 'processing_error'
    when not memory_processing_complete then 'processing'
    when personalization_enabled then 'ready'
    when my_pending_review_count > 0 then 'reviewing'
    when partner_pending_review_count > 0 then 'waiting_partner'
    else 'processing'
  end;

  return jsonb_build_object(
    'curriculum_version', active_curriculum.version,
    'completed_count', completed_count,
    'total_count', active_curriculum.question_count,
    'stage', learning_stage,
    'domain_progress', domain_progress,
    'my_consent_status', my_consent_status,
    'partner_consent_status', partner_consent_status,
    'ai_enabled', all_members_consented,
    'foundation_complete', foundation_complete,
    'memory_processing_complete', memory_processing_complete,
    'personalization_status', personalization_status,
    'personalization_enabled', personalization_enabled,
    'my_pending_review_count', my_pending_review_count,
    'partner_pending_review_count', partner_pending_review_count
  );
end;
$$;

create or replace function public.list_ai_memories()
returns table (
  memory_id uuid,
  memory_scope text,
  subject_user_id uuid,
  memory_kind text,
  memory_statement text,
  memory_confidence numeric,
  memory_state text,
  evidence_answer_ids uuid[],
  memory_created_at timestamptz,
  memory_updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  completed_count integer;
  all_members_consented boolean;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  all_members_consented := private.have_all_couple_members_granted_ai_consent(
    active_couple.id
  );

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  select count(distinct dq.question_id)::integer
  into completed_count
  from public.daily_questions as dq
  join public.questions as q on q.id = dq.question_id
  where dq.couple_id = active_couple.id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum.version;

  if completed_count < active_curriculum.question_count
    or not private.is_ai_foundation_processing_complete(
      active_couple.id,
      active_curriculum.version
    )
  then
    return;
  end if;

  return query
    select
      aim.id,
      aim.scope,
      aim.subject_user_id,
      aim.kind,
      aim.statement,
      aim.confidence,
      aim.state,
      array(
        select aime.answer_id
        from public.ai_memory_evidence as aime
        where aime.memory_id = aim.id
        order by aime.created_at, aime.answer_id
      ),
      aim.created_at,
      aim.updated_at
    from public.ai_memories as aim
    where aim.couple_id = active_couple.id
      and aim.state in ('pending', 'active')
      and private.is_ai_memory_review_eligible(aim.id)
      and (
        (
          aim.scope = 'personal'
          and aim.subject_user_id = current_user_id
        )
        or (
          all_members_consented
          and aim.scope = 'personal'
          and aim.subject_user_id <> current_user_id
          and aim.state = 'active'
        )
        or (
          all_members_consented
          and aim.scope = 'couple'
        )
      )
    order by aim.updated_at desc, aim.id;
end;
$$;

create or replace function public.confirm_ai_memory(
  requested_memory_id uuid,
  requested_decision text
)
returns table (
  memory_id uuid,
  memory_state text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  target_memory public.ai_memories%rowtype;
  normalized_decision text := btrim(requested_decision);
  next_state text;
  confirmed_member_count integer;
  completed_count integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_memory_id is null
    or normalized_decision is null
    or normalized_decision not in ('confirmed', 'rejected')
  then
    perform private.raise_app_error('invalid_ai_memory_confirmation');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  select count(distinct dq.question_id)::integer
  into completed_count
  from public.daily_questions as dq
  join public.questions as q on q.id = dq.question_id
  where dq.couple_id = active_couple.id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum.version;

  if completed_count < active_curriculum.question_count
    or not private.is_ai_foundation_processing_complete(
      active_couple.id,
      active_curriculum.version
    )
  then
    perform private.raise_app_error('ai_memory_review_not_ready');
  end if;

  select aim.*
  into target_memory
  from public.ai_memories as aim
  where aim.id = requested_memory_id
    and aim.couple_id = active_couple.id
    and aim.state = 'pending'
    and private.is_ai_memory_review_eligible(aim.id)
  for update;

  if not found then
    perform private.raise_app_error('ai_memory_not_found');
  end if;

  if target_memory.scope = 'personal'
    and target_memory.subject_user_id <> current_user_id
  then
    perform private.raise_app_error('ai_memory_confirmation_forbidden');
  end if;

  if exists (
    select 1
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = target_memory.id
      and aimc.user_id = current_user_id
  ) then
    perform private.raise_app_error('ai_memory_already_reviewed');
  end if;

  insert into public.ai_memory_confirmations (
    memory_id,
    user_id,
    decision,
    decided_at
  )
  values (
    target_memory.id,
    current_user_id,
    normalized_decision,
    now()
  );

  if normalized_decision = 'rejected' then
    next_state := 'rejected';
  elsif target_memory.scope = 'personal' then
    next_state := 'active';
  else
    select count(*)::integer
    into confirmed_member_count
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = target_memory.id
      and aimc.decision = 'confirmed'
      and aimc.user_id in (
        active_couple.user_a_id,
        active_couple.user_b_id
      );

    next_state := case
      when confirmed_member_count = 2 then 'active'
      else 'pending'
    end;
  end if;

  update public.ai_memories as aim
  set state = next_state
  where aim.id = target_memory.id;

  perform private.try_activate_ai_personalization(active_couple.id);

  return query
    select target_memory.id, next_state;
end;
$$;

create or replace function public.get_ai_learning_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  learning_progress jsonb;
  visible_memories jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  learning_progress := public.get_ai_learning_progress();

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'memory_id', memories.memory_id,
        'scope', memories.memory_scope,
        'subject_user_id', memories.subject_user_id,
        'kind', memories.memory_kind,
        'learning_domain', aim.learning_domain,
        'evidence_type', aim.evidence_type,
        'statement', memories.memory_statement,
        'confidence', memories.memory_confidence,
        'state', memories.memory_state,
        'my_decision', my_confirmation.decision,
        'confirmed_count', coalesce(confirmations.confirmed_count, 0),
        'required_confirmation_count', case
          when memories.memory_scope = 'personal' then 1
          else 2
        end,
        'can_confirm',
          (learning_progress->>'ai_enabled')::boolean
          and memories.memory_state = 'pending'
          and (
            memories.memory_scope = 'couple'
            or memories.subject_user_id = current_user_id
          )
          and my_confirmation.decision is null,
        'evidence_count', cardinality(memories.evidence_answer_ids),
        'created_at', memories.memory_created_at,
        'updated_at', memories.memory_updated_at
      )
      order by memories.memory_updated_at desc, memories.memory_id
    ),
    '[]'::jsonb
  )
  into visible_memories
  from public.list_ai_memories() as memories
  join public.ai_memories as aim on aim.id = memories.memory_id
  left join lateral (
    select aimc.decision
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = memories.memory_id
      and aimc.user_id = current_user_id
  ) as my_confirmation on true
  left join lateral (
    select
      (
        count(*) filter (
          where aimc.decision = 'confirmed'
        )
      )::integer as confirmed_count
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = memories.memory_id
  ) as confirmations on true;

  return jsonb_build_object(
    'progress', learning_progress,
    'memories', visible_memories
  );
end;
$$;

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
    with candidates as (
      select aipj.id
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
      order by aipj.available_at, aipj.created_at, aipj.id
      for update skip locked
      limit claim_limit
    )
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
      aipj.lease_expires_at;
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
  target_daily_question public.daily_questions%rowtype;
  target_question public.questions%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
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
    or target_job.daily_question_id is null
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

  select aiqc.*
  into active_curriculum
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  if not found then
    perform private.raise_app_error('ai_curriculum_unavailable');
  end if;

  select count(distinct dq.question_id)::integer
  into completed_foundation_count
  from public.daily_questions as dq
  join public.questions as q on q.id = dq.question_id
  where dq.couple_id = target_job.couple_id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum.version;

  personalization_enabled := private.is_ai_personalization_enabled(
    target_job.couple_id
  );

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
          select count(distinct dqa.daily_question_id)::integer
          from public.ai_memory_evidence as aime
          join public.daily_question_answers as dqa
            on dqa.id = aime.answer_id
          where aime.memory_id = aim.id
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
        'question_key', remaining.question_key,
        'text', remaining.question_text,
        'domain', remaining.learning_domain,
        'depth', remaining.question_depth,
        'prompt_angle', remaining.prompt_angle
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
      q.question_depth,
      q.prompt_angle,
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

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_key', recent.question_key,
        'domain', recent.learning_domain,
        'depth', recent.question_depth,
        'prompt_angle', recent.prompt_angle
      )
      order by recent.assigned_date desc, recent.daily_question_id
    ),
    '[]'::jsonb
  )
  into recent_foundation_questions_json
  from (
    select
      dq.id as daily_question_id,
      dq.assigned_date,
      q.question_key,
      q.learning_domain,
      q.question_depth,
      q.prompt_angle
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = target_job.couple_id
      and dq.status = 'completed'
      and dq.id <> target_daily_question.id
      and q.curriculum_version = active_curriculum.version
    order by dq.assigned_date desc, dq.created_at desc, dq.id
    limit 6
  ) as recent;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question', jsonb_build_object(
          'daily_question_id', recent.daily_question_id,
          'text', recent.question_text,
          'domain', recent.learning_domain
        ),
        'answers', (
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
          where dqa.daily_question_id = recent.daily_question_id
            and dqa.user_id in (
              target_couple.user_a_id,
              target_couple.user_b_id
            )
        )
      )
      order by recent.assigned_date desc, recent.daily_question_id
    ),
    '[]'::jsonb
  )
  into recent_completed_questions_json
  from (
    select
      dq.id as daily_question_id,
      dq.assigned_date,
      q.question_text,
      q.learning_domain
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where personalization_enabled
      and dq.couple_id = target_job.couple_id
      and dq.status = 'completed'
      and dq.id <> target_daily_question.id
    order by dq.assigned_date desc, dq.created_at desc, dq.id
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
        where exists (
          select 1
          from public.daily_questions as dq
          where dq.couple_id = target_job.couple_id
            and dq.question_id = q.id
            and dq.status = 'completed'
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
      'daily_question_id', target_daily_question.id,
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

create or replace function private.contains_blocked_ai_topic(
  target_text text
)
returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select lower(coalesce(target_text, '')) ~
    '(성관계|성생활|섹스|임신|출산|난임|부채|빚|정신건강|정신질환|트라우마|종교|정치|가족[[:space:]]*(갈등|다툼)|sexual|pregnan|fertility|debt|mental[[:space:]]*health|trauma|religion|politic|family[[:space:]]*conflict)';
$$;

alter function public.start_ai_processing_run(
  uuid,
  text,
  text,
  text
) rename to start_ai_processing_run_v1;

revoke execute on function public.start_ai_processing_run_v1(
  uuid,
  text,
  text,
  text
) from public, anon, authenticated, service_role;

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
  target_job public.ai_processing_jobs%rowtype;
begin
  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id;

  if target_job.job_type = 'generate_personalized_question'
    and not private.is_ai_personalization_enabled(target_job.couple_id)
  then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  return public.start_ai_processing_run_v1(
    requested_job_id,
    requested_provider,
    requested_model,
    requested_prompt_version
  );
end;
$$;

revoke execute on function public.start_ai_processing_run(
  uuid,
  text,
  text,
  text
) from public, anon, authenticated;
grant execute on function public.start_ai_processing_run(
  uuid,
  text,
  text,
  text
) to service_role;

alter function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) rename to succeed_ai_processing_run_v1;

revoke execute on function public.succeed_ai_processing_run_v1(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated, service_role;

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
  target_question public.questions%rowtype;
  output_item jsonb;
  filtered_memories jsonb;
  normalized_output jsonb := requested_output;
  target_memory public.ai_memories%rowtype;
  output_memory_key text;
  output_domain text;
  output_evidence_type text;
  output_sensitive_category text;
  metadata_changed boolean;
  completion_result boolean;
begin
  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not found then
    return false;
  end if;

  if target_run.daily_question_id is not null then
    select q.*
    into target_question
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.id = target_run.daily_question_id;
  end if;

  if target_run.task = 'extract_memories' then
    if jsonb_typeof(requested_output->'memories') <> 'array' then
      perform private.raise_app_error('invalid_ai_memory_output');
    end if;

    for output_item in
      select value
      from jsonb_array_elements(requested_output->'memories')
    loop
      output_domain := btrim(output_item->>'learning_domain');
      output_evidence_type := btrim(output_item->>'evidence_type');
      output_sensitive_category := btrim(
        output_item->>'sensitive_category'
      );

      if output_domain is null
        or output_domain not in (
          'personal_values',
          'emotional_support',
          'communication_repair',
          'daily_life',
          'relationship_strength',
          'future_boundaries'
        )
        or output_evidence_type is null
        or output_evidence_type not in ('explicit', 'repeated_pattern')
        or output_sensitive_category is null
        or output_sensitive_category <> 'none'
        or private.contains_blocked_ai_topic(output_item->>'statement')
      then
        perform private.raise_app_error('invalid_ai_memory_output');
      end if;
    end loop;

    select coalesce(jsonb_agg(candidate.value), '[]'::jsonb)
    into filtered_memories
    from jsonb_array_elements(requested_output->'memories') as candidate(value)
    where not exists (
      select 1
      from public.ai_memories as aim
      where aim.couple_id = target_run.couple_id
        and aim.memory_key = btrim(candidate.value->>'memory_key')
        and aim.state = 'rejected'
    );

    normalized_output := jsonb_set(
      requested_output,
      '{memories}',
      filtered_memories,
      true
    );
  elsif target_run.task = 'generate_feedback' then
    if char_length(btrim(requested_output->>'feedback_text')) not between 1 and 80
      or private.contains_blocked_ai_topic(requested_output->>'feedback_text')
    then
      perform private.raise_app_error('invalid_ai_feedback_output');
    end if;
  elsif target_run.task = 'generate_personalized_question' then
    if not private.is_ai_personalization_enabled(target_run.couple_id)
      or private.contains_blocked_ai_topic(requested_output->>'question_text')
      or private.contains_blocked_ai_topic(requested_output->>'category')
    then
      perform private.raise_app_error('invalid_ai_question_output');
    end if;
  end if;

  completion_result := public.succeed_ai_processing_run_v1(
    requested_run_id,
    normalized_output,
    requested_input_token_count,
    requested_output_token_count,
    requested_latency_ms
  );

  if completion_result is not true then
    return completion_result;
  end if;

  if target_run.task = 'extract_memories' then
    for output_item in
      select value
      from jsonb_array_elements(filtered_memories)
    loop
      output_memory_key := btrim(output_item->>'memory_key');
      output_domain := btrim(output_item->>'learning_domain');
      output_evidence_type := btrim(output_item->>'evidence_type');

      select aim.*
      into target_memory
      from public.ai_memories as aim
      where aim.couple_id = target_run.couple_id
        and aim.memory_key = output_memory_key
      for update;

      if not found then
        perform private.raise_app_error('invalid_ai_memory_output');
      end if;

      metadata_changed := target_memory.learning_domain is distinct from output_domain
        or target_memory.evidence_type is distinct from output_evidence_type;

      update public.ai_memories as aim
      set
        learning_domain = output_domain,
        evidence_type = output_evidence_type,
        origin_curriculum_version = coalesce(
          aim.origin_curriculum_version,
          target_question.curriculum_version
        ),
        state = case
          when metadata_changed then 'pending'
          else aim.state
        end
      where aim.id = target_memory.id;

      if metadata_changed then
        delete from public.ai_memory_confirmations as aimc
        where aimc.memory_id = target_memory.id;

        delete from public.ai_memory_evidence as aime
        where aime.memory_id = target_memory.id
          and not exists (
            select 1
            from jsonb_array_elements_text(
              output_item->'evidence_answer_ids'
            ) as evidence(answer_id)
            where evidence.answer_id::uuid = aime.answer_id
          );
      end if;
    end loop;

    perform private.try_activate_ai_personalization(target_run.couple_id);
  end if;

  return true;
end;
$$;

revoke execute on function private.contains_blocked_ai_topic(text)
  from public, anon, authenticated;
revoke execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) from public, anon, authenticated;
grant execute on function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) to service_role;

alter function public.create_ai_question_candidate(
  uuid,
  text,
  text,
  text,
  text
) rename to create_ai_question_candidate_v1;

revoke execute on function public.create_ai_question_candidate_v1(
  uuid,
  text,
  text,
  text,
  text
) from public, anon, authenticated, service_role;

create or replace function public.create_ai_question_candidate(
  requested_run_id uuid,
  requested_question_key text,
  requested_question_text text,
  requested_category text,
  requested_mood text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_question_id uuid;
  target_couple_id uuid;
begin
  target_question_id := public.create_ai_question_candidate_v1(
    requested_run_id,
    requested_question_key,
    requested_question_text,
    requested_category,
    requested_mood
  );

  select air.couple_id
  into target_couple_id
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not private.is_ai_personalization_enabled(target_couple_id) then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  return target_question_id;
end;
$$;

alter function public.record_ai_question_recommendation(
  uuid,
  uuid,
  uuid,
  text
) rename to record_ai_question_recommendation_v1;

revoke execute on function public.record_ai_question_recommendation_v1(
  uuid,
  uuid,
  uuid,
  text
) from public, anon, authenticated, service_role;

create or replace function public.record_ai_question_recommendation(
  requested_run_id uuid,
  requested_couple_id uuid,
  requested_question_id uuid,
  requested_reason text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  recommendation_id uuid;
  target_run_task text;
begin
  recommendation_id := public.record_ai_question_recommendation_v1(
    requested_run_id,
    requested_couple_id,
    requested_question_id,
    requested_reason
  );

  select air.task
  into target_run_task
  from public.ai_runs as air
  where air.id = requested_run_id;

  if target_run_task = 'generate_personalized_question'
    and not private.is_ai_personalization_enabled(requested_couple_id)
  then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  return recommendation_id;
end;
$$;

revoke execute on function public.create_ai_question_candidate(
  uuid,
  text,
  text,
  text,
  text
) from public, anon, authenticated;
revoke execute on function public.record_ai_question_recommendation(
  uuid,
  uuid,
  uuid,
  text
) from public, anon, authenticated;
grant execute on function public.create_ai_question_candidate(
  uuid,
  text,
  text,
  text,
  text
) to service_role;
grant execute on function public.record_ai_question_recommendation(
  uuid,
  uuid,
  uuid,
  text
) to service_role;
