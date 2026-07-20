create table public.ai_user_consents (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'revoked',
  policy_version text not null,
  revision integer not null default 1,
  granted_at timestamptz,
  revoked_at timestamptz default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (couple_id, user_id),
  constraint ai_user_consents_status_check
    check (status in ('granted', 'revoked')),
  constraint ai_user_consents_policy_version_check
    check (char_length(btrim(policy_version)) between 1 and 100),
  constraint ai_user_consents_revision_check
    check (revision >= 1),
  constraint ai_user_consents_timestamps_check
    check (
      (status = 'granted' and granted_at is not null and revoked_at is null)
      or (status = 'revoked' and revoked_at is not null)
    )
);

create index ai_user_consents_user_idx
  on public.ai_user_consents (user_id, updated_at desc);

alter table public.ai_user_consents enable row level security;

create trigger ai_user_consents_set_updated_at
  before update on public.ai_user_consents
  for each row
  execute function public.set_updated_at();

create policy "ai_user_consents_select_own"
  on public.ai_user_consents
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create table public.ai_processing_jobs (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  daily_question_id uuid
    references public.daily_questions(id) on delete cascade,
  job_type text not null,
  status text not null default 'pending',
  deduplication_key text not null unique,
  attempts integer not null default 0,
  max_attempts integer not null default 3,
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  claimed_by text,
  lease_expires_at timestamptz,
  completed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_processing_jobs_type_check
    check (
      job_type in (
        'extract_memories',
        'generate_feedback',
        'select_curated_question',
        'generate_personalized_question',
        'rebuild_profile'
      )
    ),
  constraint ai_processing_jobs_status_check
    check (
      status in (
        'pending',
        'processing',
        'succeeded',
        'failed',
        'cancelled'
      )
    ),
  constraint ai_processing_jobs_deduplication_key_check
    check (char_length(btrim(deduplication_key)) between 1 and 300),
  constraint ai_processing_jobs_attempts_check
    check (attempts >= 0 and max_attempts between 1 and 10),
  constraint ai_processing_jobs_claimed_by_check
    check (
      claimed_by is null
      or char_length(btrim(claimed_by)) between 1 and 120
    ),
  constraint ai_processing_jobs_last_error_check
    check (last_error is null or char_length(last_error) <= 1000)
);

create index ai_processing_jobs_claim_idx
  on public.ai_processing_jobs (status, available_at, created_at)
  where status in ('pending', 'processing');

create index ai_processing_jobs_couple_idx
  on public.ai_processing_jobs (couple_id, created_at desc);

alter table public.ai_processing_jobs enable row level security;

create trigger ai_processing_jobs_set_updated_at
  before update on public.ai_processing_jobs
  for each row
  execute function public.set_updated_at();

create table public.ai_runs (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.ai_processing_jobs(id) on delete set null,
  couple_id uuid not null references public.couples(id) on delete cascade,
  daily_question_id uuid
    references public.daily_questions(id) on delete set null,
  task text not null,
  provider text not null,
  model text not null,
  prompt_version text not null,
  status text not null default 'started',
  input_answer_ids uuid[] not null default '{}',
  input_token_count integer,
  output_token_count integer,
  latency_ms integer,
  safety_status text not null default 'pending',
  error_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),

  constraint ai_runs_task_check
    check (
      task in (
        'extract_memories',
        'generate_feedback',
        'select_curated_question',
        'generate_personalized_question',
        'rebuild_profile'
      )
    ),
  constraint ai_runs_provider_check
    check (char_length(btrim(provider)) between 1 and 100),
  constraint ai_runs_model_check
    check (char_length(btrim(model)) between 1 and 160),
  constraint ai_runs_prompt_version_check
    check (char_length(btrim(prompt_version)) between 1 and 100),
  constraint ai_runs_status_check
    check (status in ('started', 'succeeded', 'failed', 'cancelled')),
  constraint ai_runs_token_counts_check
    check (
      (input_token_count is null or input_token_count >= 0)
      and (output_token_count is null or output_token_count >= 0)
      and (latency_ms is null or latency_ms >= 0)
    ),
  constraint ai_runs_safety_status_check
    check (safety_status in ('pending', 'passed', 'flagged', 'error')),
  constraint ai_runs_error_code_check
    check (
      error_code is null
      or char_length(btrim(error_code)) between 1 and 160
    )
);

create index ai_runs_couple_created_idx
  on public.ai_runs (couple_id, created_at desc);

create index ai_runs_job_idx
  on public.ai_runs (job_id, created_at desc)
  where job_id is not null;

alter table public.ai_runs enable row level security;

alter table public.questions
  add column personalized_for_couple_id uuid
    references public.couples(id) on delete set null,
  add column generated_by_run_id uuid
    references public.ai_runs(id) on delete set null;

alter table public.questions
  add constraint questions_ai_provenance_check
    check (
      (
        source = 'curated'
        and personalized_for_couple_id is null
        and generated_by_run_id is null
      )
      or (
        source = 'ai'
        and question_key is not null
        and (
          is_active = false
          or (
            personalized_for_couple_id is not null
            and generated_by_run_id is not null
          )
        )
      )
    );

create index questions_personalized_couple_idx
  on public.questions (personalized_for_couple_id, created_at desc)
  where personalized_for_couple_id is not null;

create or replace function private.deactivate_orphaned_ai_question()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.source = 'ai'
    and (
      new.personalized_for_couple_id is null
      or new.generated_by_run_id is null
    )
  then
    new.is_active := false;
  end if;

  return new;
end;
$$;

create trigger questions_deactivate_orphaned_ai_question
  before update on public.questions
  for each row
  execute function private.deactivate_orphaned_ai_question();

create table public.ai_memories (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  scope text not null,
  subject_user_id uuid references auth.users(id) on delete cascade,
  memory_key text not null,
  kind text not null,
  statement text not null,
  confidence numeric(4, 3) not null,
  state text not null default 'pending',
  source_run_id uuid not null references public.ai_runs(id),
  observed_at timestamptz not null,
  last_observed_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_memories_couple_key_unique unique (couple_id, memory_key),
  constraint ai_memories_scope_check
    check (scope in ('personal', 'couple')),
  constraint ai_memories_subject_check
    check (
      (scope = 'personal' and subject_user_id is not null)
      or (scope = 'couple' and subject_user_id is null)
    ),
  constraint ai_memories_key_check
    check (char_length(btrim(memory_key)) between 1 and 160),
  constraint ai_memories_kind_check
    check (char_length(btrim(kind)) between 1 and 100),
  constraint ai_memories_statement_check
    check (char_length(btrim(statement)) between 1 and 500),
  constraint ai_memories_confidence_check
    check (confidence between 0 and 1),
  constraint ai_memories_state_check
    check (state in ('pending', 'active', 'rejected', 'superseded')),
  constraint ai_memories_observation_check
    check (last_observed_at >= observed_at)
);

create index ai_memories_couple_state_idx
  on public.ai_memories (couple_id, state, updated_at desc);

create index ai_memories_subject_state_idx
  on public.ai_memories (subject_user_id, state, updated_at desc)
  where subject_user_id is not null;

alter table public.ai_memories enable row level security;

create trigger ai_memories_set_updated_at
  before update on public.ai_memories
  for each row
  execute function public.set_updated_at();

create table public.ai_memory_evidence (
  memory_id uuid not null references public.ai_memories(id) on delete cascade,
  answer_id uuid not null
    references public.daily_question_answers(id) on delete cascade,
  relevance numeric(4, 3) not null default 1,
  created_at timestamptz not null default now(),

  primary key (memory_id, answer_id),
  constraint ai_memory_evidence_relevance_check
    check (relevance between 0 and 1)
);

create index ai_memory_evidence_answer_idx
  on public.ai_memory_evidence (answer_id);

alter table public.ai_memory_evidence enable row level security;

create table public.ai_memory_confirmations (
  memory_id uuid not null references public.ai_memories(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  decision text not null,
  decided_at timestamptz not null default now(),

  primary key (memory_id, user_id),
  constraint ai_memory_confirmations_decision_check
    check (decision in ('confirmed', 'rejected'))
);

create index ai_memory_confirmations_user_idx
  on public.ai_memory_confirmations (user_id, decided_at desc);

alter table public.ai_memory_confirmations enable row level security;

create table public.ai_question_feedbacks (
  daily_question_id uuid primary key
    references public.daily_questions(id) on delete cascade,
  couple_id uuid not null references public.couples(id) on delete cascade,
  feedback_text text not null,
  state text not null default 'pending',
  safety_status text not null default 'pending',
  source_run_id uuid not null references public.ai_runs(id),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_question_feedbacks_text_check
    check (char_length(btrim(feedback_text)) between 1 and 500),
  constraint ai_question_feedbacks_state_check
    check (state in ('pending', 'published', 'rejected')),
  constraint ai_question_feedbacks_safety_check
    check (safety_status in ('pending', 'passed', 'flagged', 'error')),
  constraint ai_question_feedbacks_publish_check
    check (
      (state = 'published' and published_at is not null and safety_status = 'passed')
      or state <> 'published'
    )
);

create index ai_question_feedbacks_couple_idx
  on public.ai_question_feedbacks (couple_id, created_at desc);

alter table public.ai_question_feedbacks enable row level security;

create trigger ai_question_feedbacks_set_updated_at
  before update on public.ai_question_feedbacks
  for each row
  execute function public.set_updated_at();

create policy "ai_question_feedbacks_select_completed_member"
  on public.ai_question_feedbacks
  for select
  to authenticated
  using (
    state = 'published'
    and private.is_readable_couple_member(couple_id, (select auth.uid()))
    and exists (
      select 1
      from public.daily_questions as dq
      where dq.id = daily_question_id
        and dq.status = 'completed'
    )
  );

create table public.ai_question_recommendations (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  source_run_id uuid not null references public.ai_runs(id),
  reason text not null,
  status text not null default 'pending',
  assigned_daily_question_id uuid
    references public.daily_questions(id) on delete set null,
  expires_at timestamptz not null default (now() + interval '14 days'),
  used_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_question_recommendations_reason_check
    check (char_length(btrim(reason)) between 1 and 500),
  constraint ai_question_recommendations_status_check
    check (status in ('pending', 'used', 'cancelled', 'expired')),
  constraint ai_question_recommendations_usage_check
    check (
      (
        status = 'used'
        and assigned_daily_question_id is not null
        and used_at is not null
      )
      or status <> 'used'
    )
);

create unique index ai_question_recommendations_one_pending_idx
  on public.ai_question_recommendations (couple_id)
  where status = 'pending';

create index ai_question_recommendations_question_idx
  on public.ai_question_recommendations (question_id, created_at desc);

alter table public.ai_question_recommendations enable row level security;

create trigger ai_question_recommendations_set_updated_at
  before update on public.ai_question_recommendations
  for each row
  execute function public.set_updated_at();

create or replace function private.have_all_couple_members_granted_ai_consent(
  target_couple_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.couples as c
    where c.id = target_couple_id
      and c.status = 'active'
      and c.user_b_id is not null
      and (
        select count(*)
        from public.ai_user_consents as auc
        where auc.couple_id = c.id
          and auc.user_id in (c.user_a_id, c.user_b_id)
          and auc.status = 'granted'
      ) = 2
  );
$$;

create or replace function private.is_readable_personalized_question(
  target_question_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.questions as q
    where q.id = target_question_id
      and q.source = 'ai'
      and q.personalized_for_couple_id is not null
      and private.is_readable_couple_member(
        q.personalized_for_couple_id,
        target_user_id
      )
  );
$$;

create or replace function private.is_readable_assigned_question(
  target_question_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.daily_questions as dq
    where dq.question_id = target_question_id
      and private.is_readable_couple_member(dq.couple_id, target_user_id)
  );
$$;

drop policy if exists "questions_select_active_authenticated"
  on public.questions;

create policy "questions_select_active_authenticated"
  on public.questions
  for select
  to authenticated
  using (
    (
      is_active = true
      and (
        source = 'curated'
        or private.is_readable_personalized_question(
          id,
          (select auth.uid())
        )
      )
    )
    or private.is_readable_assigned_question(
        id,
        (select auth.uid())
    )
  );

create or replace function private.enqueue_ai_processing_job(
  requested_couple_id uuid,
  requested_daily_question_id uuid,
  requested_job_type text,
  requested_deduplication_key text,
  requested_available_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_job_type text := btrim(requested_job_type);
  normalized_deduplication_key text := btrim(requested_deduplication_key);
  target_job_id uuid;
begin
  if requested_couple_id is null
    or normalized_job_type is null
    or normalized_job_type not in (
      'extract_memories',
      'generate_feedback',
      'select_curated_question',
      'generate_personalized_question',
      'rebuild_profile'
    )
    or normalized_deduplication_key is null
    or char_length(normalized_deduplication_key) not between 1 and 300
  then
    perform private.raise_app_error('invalid_ai_job');
  end if;

  if not private.have_all_couple_members_granted_ai_consent(
    requested_couple_id
  ) then
    return null;
  end if;

  if requested_daily_question_id is not null
    and not exists (
      select 1
      from public.daily_questions as dq
      where dq.id = requested_daily_question_id
        and dq.couple_id = requested_couple_id
        and dq.status = 'completed'
    )
  then
    perform private.raise_app_error('invalid_ai_job_question');
  end if;

  insert into public.ai_processing_jobs (
    couple_id,
    daily_question_id,
    job_type,
    deduplication_key,
    available_at
  )
  values (
    requested_couple_id,
    requested_daily_question_id,
    normalized_job_type,
    normalized_deduplication_key,
    coalesce(requested_available_at, now())
  )
  on conflict (deduplication_key) do nothing
  returning id into target_job_id;

  if target_job_id is null then
    select aipj.id
    into target_job_id
    from public.ai_processing_jobs as aipj
    where aipj.deduplication_key = normalized_deduplication_key;
  end if;

  return target_job_id;
end;
$$;

create or replace function public.set_my_ai_consent(
  requested_granted boolean,
  requested_policy_version text
)
returns table (
  consent_status text,
  consent_revision integer,
  consent_policy_version text,
  consent_updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  normalized_policy_version text := btrim(requested_policy_version);
  requested_status text;
  current_consent public.ai_user_consents%rowtype;
  saved_consent public.ai_user_consents%rowtype;
  user_a_revision integer;
  user_b_revision integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_granted is null
    or normalized_policy_version is null
    or char_length(normalized_policy_version) not between 1 and 100
  then
    perform private.raise_app_error('invalid_ai_consent');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  perform pg_advisory_xact_lock(
    hashtext('ai_consent'),
    hashtext(active_couple.id::text)
  );

  requested_status := case
    when requested_granted then 'granted'
    else 'revoked'
  end;

  select auc.*
  into current_consent
  from public.ai_user_consents as auc
  where auc.couple_id = active_couple.id
    and auc.user_id = current_user_id
  for update;

  if found
    and current_consent.status = requested_status
    and current_consent.policy_version = normalized_policy_version
  then
    saved_consent := current_consent;
  elsif found then
    update public.ai_user_consents as auc
    set
      status = requested_status,
      policy_version = normalized_policy_version,
      revision = auc.revision + 1,
      granted_at = case
        when requested_granted then now()
        else auc.granted_at
      end,
      revoked_at = case
        when requested_granted then null
        else now()
      end
    where auc.couple_id = active_couple.id
      and auc.user_id = current_user_id
    returning auc.* into saved_consent;
  else
    insert into public.ai_user_consents (
      couple_id,
      user_id,
      status,
      policy_version,
      revision,
      granted_at,
      revoked_at
    )
    values (
      active_couple.id,
      current_user_id,
      requested_status,
      normalized_policy_version,
      1,
      case when requested_granted then now() else null end,
      case when requested_granted then null else now() end
    )
    returning * into saved_consent;
  end if;

  if requested_granted = false then
    update public.ai_processing_jobs as aipj
    set
      status = 'cancelled',
      completed_at = now(),
      lease_expires_at = null,
      last_error = 'ai_consent_revoked'
    where aipj.couple_id = active_couple.id
      and aipj.status in ('pending', 'processing');

    update public.ai_question_recommendations as aiqr
    set status = 'cancelled'
    where aiqr.couple_id = active_couple.id
      and aiqr.status = 'pending';
  elsif private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    select auc.revision
    into user_a_revision
    from public.ai_user_consents as auc
    where auc.couple_id = active_couple.id
      and auc.user_id = active_couple.user_a_id;

    select auc.revision
    into user_b_revision
    from public.ai_user_consents as auc
    where auc.couple_id = active_couple.id
      and auc.user_id = active_couple.user_b_id;

    perform private.enqueue_ai_processing_job(
      active_couple.id,
      null,
      'rebuild_profile',
      'rebuild_profile:'
        || active_couple.id::text
        || ':'
        || user_a_revision::text
        || ':'
        || user_b_revision::text
    );
  end if;

  return query
    select
      saved_consent.status,
      saved_consent.revision,
      saved_consent.policy_version,
      saved_consent.updated_at;
end;
$$;

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
  join public.questions as q
    on q.id = dq.question_id
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
        'completed_count',
        domain_rows.completed_count,
        'total_count',
        domain_rows.total_count
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

  return jsonb_build_object(
    'curriculum_version', active_curriculum.version,
    'completed_count', completed_count,
    'total_count', active_curriculum.question_count,
    'stage', learning_stage,
    'domain_progress', domain_progress,
    'my_consent_status', my_consent_status,
    'partner_consent_status', partner_consent_status,
    'ai_enabled', private.have_all_couple_members_granted_ai_consent(
      active_couple.id
    )
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
  all_members_consented boolean;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  all_members_consented := private.have_all_couple_members_granted_ai_consent(
    active_couple.id
  );

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
      and (
        (
          aim.scope = 'personal'
          and aim.subject_user_id = current_user_id
          and aim.state in ('pending', 'active')
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
          and aim.state in ('pending', 'active')
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
  target_memory public.ai_memories%rowtype;
  normalized_decision text := btrim(requested_decision);
  next_state text;
  confirmed_member_count integer;
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

  select aim.*
  into target_memory
  from public.ai_memories as aim
  where aim.id = requested_memory_id
    and aim.couple_id = active_couple.id
    and aim.state <> 'superseded'
  for update;

  if not found then
    perform private.raise_app_error('ai_memory_not_found');
  end if;

  if target_memory.scope = 'personal'
    and target_memory.subject_user_id <> current_user_id
  then
    perform private.raise_app_error('ai_memory_confirmation_forbidden');
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
  )
  on conflict on constraint ai_memory_confirmations_pkey do update
  set
    decision = excluded.decision,
    decided_at = excluded.decided_at;

  if exists (
    select 1
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = target_memory.id
      and aimc.decision = 'rejected'
  ) then
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

  return query
    select target_memory.id, next_state;
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

create or replace function public.complete_ai_processing_job(
  requested_job_id uuid,
  requested_result text,
  requested_error text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_result text := btrim(requested_result);
  normalized_error text := nullif(left(btrim(requested_error), 1000), '');
  target_job public.ai_processing_jobs%rowtype;
begin
  if requested_job_id is null
    or normalized_result is null
    or normalized_result not in ('succeeded', 'failed', 'cancelled')
  then
    perform private.raise_app_error('invalid_ai_job_completion');
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id
  for update;

  if not found or target_job.status <> 'processing' then
    return false;
  end if;

  if normalized_result = 'succeeded'
    and not private.have_all_couple_members_granted_ai_consent(
      target_job.couple_id
    )
  then
    normalized_result := 'cancelled';
    normalized_error := 'ai_consent_revoked';
  end if;

  if normalized_result = 'failed'
    and target_job.attempts < target_job.max_attempts
  then
    update public.ai_processing_jobs as aipj
    set
      status = 'pending',
      available_at = now() + (target_job.attempts * interval '30 seconds'),
      claimed_at = null,
      claimed_by = null,
      lease_expires_at = null,
      completed_at = null,
      last_error = coalesce(normalized_error, 'ai_job_failed')
    where aipj.id = target_job.id;

    return true;
  end if;

  update public.ai_processing_jobs as aipj
  set
    status = normalized_result,
    completed_at = now(),
    lease_expires_at = null,
    last_error = case
      when normalized_result = 'succeeded' then null
      when normalized_result = 'cancelled'
        then coalesce(normalized_error, 'ai_job_cancelled')
      else coalesce(normalized_error, 'ai_job_failed')
    end
  where aipj.id = target_job.id;

  return true;
end;
$$;

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
  normalized_key text := btrim(requested_question_key);
  normalized_text text := btrim(requested_question_text);
  normalized_category text := btrim(requested_category);
  normalized_mood text := nullif(btrim(requested_mood), '');
  target_run public.ai_runs%rowtype;
  target_question_id uuid;
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
begin
  if requested_run_id is null
    or normalized_key is null
    or char_length(normalized_key) not between 1 and 120
    or normalized_text is null
    or char_length(normalized_text) not between 1 and 300
    or normalized_category is null
    or char_length(normalized_category) not between 1 and 100
  then
    perform private.raise_app_error('invalid_ai_question_candidate');
  end if;

  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id
    and air.task = 'generate_personalized_question'
    and air.status = 'succeeded'
    and air.safety_status = 'passed';

  if not found
    or not private.have_all_couple_members_granted_ai_consent(
      target_run.couple_id
    )
  then
    perform private.raise_app_error('invalid_ai_question_run');
  end if;

  select aiqc.version, aiqc.question_count
  into active_curriculum_version, foundation_question_count
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  select count(distinct dq.question_id)::integer
  into completed_foundation_count
  from public.daily_questions as dq
  join public.questions as q
    on q.id = dq.question_id
  where dq.couple_id = target_run.couple_id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum_version;

  if active_curriculum_version is null
    or completed_foundation_count < foundation_question_count
  then
    perform private.raise_app_error('ai_foundation_incomplete');
  end if;

  insert into public.questions (
    source,
    question_key,
    question_text,
    category,
    mood,
    is_active,
    personalized_for_couple_id,
    generated_by_run_id
  )
  values (
    'ai',
    normalized_key,
    normalized_text,
    normalized_category,
    normalized_mood,
    true,
    target_run.couple_id,
    target_run.id
  )
  returning id into target_question_id;

  return target_question_id;
end;
$$;

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
  normalized_reason text := btrim(requested_reason);
  target_run_task text;
  active_curriculum_version integer;
  foundation_question_count integer;
  completed_foundation_count integer;
  recommendation_id uuid;
begin
  if requested_run_id is null
    or requested_couple_id is null
    or requested_question_id is null
    or normalized_reason is null
    or char_length(normalized_reason) not between 1 and 500
  then
    perform private.raise_app_error('invalid_ai_question_recommendation');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(requested_couple_id::text)
  );

  if not private.have_all_couple_members_granted_ai_consent(
    requested_couple_id
  ) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  select air.task
  into target_run_task
  from public.ai_runs as air
  where air.id = requested_run_id
    and air.couple_id = requested_couple_id
    and air.task in (
      'select_curated_question',
      'generate_personalized_question'
    )
    and air.status = 'succeeded'
    and air.safety_status = 'passed';

  if not found then
    perform private.raise_app_error('invalid_ai_question_run');
  end if;

  select aiqc.version, aiqc.question_count
  into active_curriculum_version, foundation_question_count
  from public.ai_question_curricula as aiqc
  where aiqc.status = 'active'
  order by aiqc.version desc
  limit 1;

  select count(distinct dq.question_id)::integer
  into completed_foundation_count
  from public.daily_questions as dq
  join public.questions as q
    on q.id = dq.question_id
  where dq.couple_id = requested_couple_id
    and dq.status = 'completed'
    and q.curriculum_version = active_curriculum_version;

  if active_curriculum_version is null then
    perform private.raise_app_error('ai_curriculum_unavailable');
  end if;

  perform 1
  from public.questions as q
  where q.id = requested_question_id
    and q.is_active = true
    and (
      (
        target_run_task = 'select_curated_question'
        and completed_foundation_count < foundation_question_count
        and q.source = 'curated'
        and q.curriculum_version = active_curriculum_version
      )
      or (
        target_run_task = 'generate_personalized_question'
        and completed_foundation_count >= foundation_question_count
        and q.source = 'ai'
        and q.personalized_for_couple_id = requested_couple_id
        and q.generated_by_run_id = requested_run_id
      )
    );

  if not found then
    perform private.raise_app_error('invalid_ai_question_candidate');
  end if;

  if exists (
    select 1
    from public.daily_questions as dq
    where dq.couple_id = requested_couple_id
      and dq.question_id = requested_question_id
  ) then
    perform private.raise_app_error('ai_question_already_used');
  end if;

  update public.ai_question_recommendations as aiqr
  set status = 'cancelled'
  where aiqr.couple_id = requested_couple_id
    and aiqr.status = 'pending';

  insert into public.ai_question_recommendations (
    couple_id,
    question_id,
    source_run_id,
    reason
  )
  values (
    requested_couple_id,
    requested_question_id,
    requested_run_id,
    normalized_reason
  )
  returning id into recommendation_id;

  return recommendation_id;
end;
$$;

revoke execute on function private.deactivate_orphaned_ai_question()
  from public, anon, authenticated;
revoke execute on function private.have_all_couple_members_granted_ai_consent(uuid)
  from public, anon, authenticated;
revoke execute on function private.is_readable_personalized_question(uuid, uuid)
  from public, anon;
grant execute on function private.is_readable_personalized_question(uuid, uuid)
  to authenticated;
revoke execute on function private.is_readable_assigned_question(uuid, uuid)
  from public, anon;
grant execute on function private.is_readable_assigned_question(uuid, uuid)
  to authenticated;
revoke execute on function private.enqueue_ai_processing_job(
  uuid,
  uuid,
  text,
  text,
  timestamptz
) from public, anon, authenticated;

revoke execute on function public.set_my_ai_consent(boolean, text)
  from public, anon;
revoke execute on function public.get_ai_learning_progress()
  from public, anon;
revoke execute on function public.list_ai_memories()
  from public, anon;
revoke execute on function public.confirm_ai_memory(uuid, text)
  from public, anon;

grant execute on function public.set_my_ai_consent(boolean, text)
  to authenticated;
grant execute on function public.get_ai_learning_progress()
  to authenticated;
grant execute on function public.list_ai_memories()
  to authenticated;
grant execute on function public.confirm_ai_memory(uuid, text)
  to authenticated;

revoke execute on function public.claim_ai_processing_jobs(text, integer)
  from public, anon, authenticated;
revoke execute on function public.complete_ai_processing_job(uuid, text, text)
  from public, anon, authenticated;
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

grant execute on function public.claim_ai_processing_jobs(text, integer)
  to service_role;
grant execute on function public.complete_ai_processing_job(uuid, text, text)
  to service_role;
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
