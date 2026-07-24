create table public.ai_user_questions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  requester_user_id uuid not null references auth.users(id) on delete cascade,
  question_text text not null,
  status text not null default 'queued',
  answer_text text,
  failure_code text,
  answered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_user_questions_text_check
    check (char_length(btrim(question_text)) between 1 and 300),
  constraint ai_user_questions_status_check
    check (status in ('queued', 'processing', 'completed', 'failed')),
  constraint ai_user_questions_answer_check
    check (
      (
        status = 'completed'
        and answer_text is not null
        and char_length(btrim(answer_text)) between 1 and 400
        and answered_at is not null
        and failure_code is null
      )
      or (
        status <> 'completed'
        and answer_text is null
        and answered_at is null
      )
    ),
  constraint ai_user_questions_failure_check
    check (
      (
        status = 'failed'
        and failure_code is not null
        and char_length(btrim(failure_code)) between 1 and 160
      )
      or (
        status <> 'failed'
        and failure_code is null
      )
    )
);

create index ai_user_questions_requester_created_idx
  on public.ai_user_questions (requester_user_id, created_at desc);

create index ai_user_questions_couple_status_idx
  on public.ai_user_questions (couple_id, status, created_at);

alter table public.ai_user_questions enable row level security;

create trigger ai_user_questions_set_updated_at
  before update on public.ai_user_questions
  for each row
  execute function public.set_updated_at();

revoke all on table public.ai_user_questions
  from public, anon, authenticated;
grant all on table public.ai_user_questions to service_role;

create table public.ai_user_question_daily_usage (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  context_date date not null,
  submission_count smallint not null default 0,
  updated_at timestamptz not null default now(),

  primary key (couple_id, user_id, context_date),
  constraint ai_user_question_daily_usage_count_check
    check (submission_count between 0 and 3)
);

alter table public.ai_user_question_daily_usage enable row level security;

create trigger ai_user_question_daily_usage_set_updated_at
  before update on public.ai_user_question_daily_usage
  for each row
  execute function public.set_updated_at();

revoke all on table public.ai_user_question_daily_usage
  from public, anon, authenticated;
grant all on table public.ai_user_question_daily_usage to service_role;

alter table public.ai_processing_jobs
  add column user_question_id uuid
    references public.ai_user_questions(id) on delete cascade;

alter table public.ai_runs
  add column user_question_id uuid
    references public.ai_user_questions(id) on delete cascade;

create index ai_processing_jobs_user_question_idx
  on public.ai_processing_jobs (user_question_id)
  where user_question_id is not null;

create index ai_runs_user_question_idx
  on public.ai_runs (user_question_id)
  where user_question_id is not null;

alter table public.ai_processing_jobs
  drop constraint ai_processing_jobs_type_check;

alter table public.ai_processing_jobs
  add constraint ai_processing_jobs_type_check
    check (
      job_type in (
        'extract_memories',
        'generate_feedback',
        'select_curated_question',
        'generate_general_question',
        'generate_personalized_question',
        'answer_user_question',
        'rebuild_profile'
      )
    );

alter table public.ai_runs
  drop constraint ai_runs_task_check;

alter table public.ai_runs
  add constraint ai_runs_task_check
    check (
      task in (
        'extract_memories',
        'generate_feedback',
        'select_curated_question',
        'generate_general_question',
        'generate_personalized_question',
        'answer_user_question',
        'rebuild_profile'
      )
    );

alter table public.ai_processing_jobs
  drop constraint ai_processing_jobs_question_source_check;

alter table public.ai_processing_jobs
  add constraint ai_processing_jobs_question_source_check
    check (
      (
        job_type = 'rebuild_profile'
        and num_nonnulls(
          daily_question_id,
          focused_question_id,
          user_question_id
        ) = 0
      )
      or (
        job_type = 'answer_user_question'
        and user_question_id is not null
        and daily_question_id is null
        and focused_question_id is null
      )
      or (
        job_type not in ('rebuild_profile', 'answer_user_question')
        and user_question_id is null
        and num_nonnulls(daily_question_id, focused_question_id) = 1
      )
    );

alter table public.ai_runs
  drop constraint ai_runs_question_source_check;

alter table public.ai_runs
  add constraint ai_runs_question_source_check
    check (
      (
        task = 'answer_user_question'
        and user_question_id is not null
        and daily_question_id is null
        and focused_question_id is null
      )
      or (
        task <> 'answer_user_question'
        and user_question_id is null
        and num_nonnulls(daily_question_id, focused_question_id) = 1
      )
    );

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
      when 'answer_user_question' then 5
      when 'generate_feedback' then 10
      when 'select_curated_question' then 20
      when 'generate_general_question' then 20
      when 'generate_personalized_question' then 20
      when 'extract_memories' then 30
      else 100
    end
  )::smallint;
$$;

create or replace function private.ai_question_contains_blocked_topic(
  requested_question text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(requested_question, '') ~* (
    '(성관계|성생활|섹스|임신|출산|난임'
    || '|부채|빚|정신[[:space:]]*건강|정신[[:space:]]*질환'
    || '|트라우마|종교|정치'
    || '|가족[[:space:]]*(갈등|다툼|불화)'
    || '|sexual|pregnan|fertility|debt'
    || '|mental[[:space:]]*health|trauma|religion|politic'
    || '|family[[:space:]]*conflict)'
  );
$$;

create or replace function private.sync_ai_user_question_job_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.job_type <> 'answer_user_question'
    or new.user_question_id is null
  then
    return new;
  end if;

  if new.status = 'pending' then
    update public.ai_user_questions
    set
      status = 'queued',
      failure_code = null
    where id = new.user_question_id
      and status <> 'completed';
  elsif new.status = 'processing' then
    update public.ai_user_questions
    set
      status = 'processing',
      failure_code = null
    where id = new.user_question_id
      and status <> 'completed';
  elsif new.status in ('failed', 'cancelled') then
    update public.ai_user_questions
    set
      status = 'failed',
      failure_code = left(
        coalesce(
          nullif(btrim(new.last_error), ''),
          'ai_answer_failed'
        ),
        160
      )
    where id = new.user_question_id
      and status <> 'completed';
  end if;

  return new;
end;
$$;

create trigger ai_processing_jobs_sync_user_question_status
  after insert or update of status, last_error
  on public.ai_processing_jobs
  for each row
  execute function private.sync_ai_user_question_job_status();

create or replace function public.submit_ai_user_question(
  requested_question_text text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  normalized_question text := btrim(requested_question_text);
  current_couple_date date;
  submitted_today_count smallint;
  created_question public.ai_user_questions%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.is_ai_personalization_enabled(active_couple.id) then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  if normalized_question is null or char_length(normalized_question) = 0 then
    perform private.raise_app_error('question_required');
  end if;

  if char_length(normalized_question) > 300 then
    perform private.raise_app_error('question_too_long');
  end if;

  if private.ai_question_contains_blocked_topic(normalized_question) then
    perform private.raise_app_error('ai_sensitive_question_not_available');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  insert into public.ai_user_question_daily_usage (
    couple_id,
    user_id,
    context_date,
    submission_count
  )
  values (
    active_couple.id,
    current_user_id,
    current_couple_date,
    1
  )
  on conflict (couple_id, user_id, context_date)
  do update
  set submission_count =
    public.ai_user_question_daily_usage.submission_count + 1
  where public.ai_user_question_daily_usage.submission_count < 3
  returning submission_count into submitted_today_count;

  if not found then
    perform private.raise_app_error('ai_daily_question_limit_reached');
  end if;

  insert into public.ai_user_questions (
    couple_id,
    requester_user_id,
    question_text
  )
  values (
    active_couple.id,
    current_user_id,
    normalized_question
  )
  returning * into created_question;

  insert into public.ai_processing_jobs (
    couple_id,
    user_question_id,
    job_type,
    deduplication_key,
    max_attempts
  )
  values (
    active_couple.id,
    created_question.id,
    'answer_user_question',
    'direct-question:' || created_question.id::text,
    5
  );

  return jsonb_build_object(
    'question', jsonb_build_object(
      'id', created_question.id,
      'question_text', created_question.question_text,
      'status', created_question.status,
      'answer_text', created_question.answer_text,
      'failure_code', created_question.failure_code,
      'created_at', created_question.created_at,
      'answered_at', created_question.answered_at
    ),
    'daily_limit', 3,
    'remaining_count', greatest(0, 3 - submitted_today_count)
  );
end;
$$;

create or replace function public.get_my_ai_user_questions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  submitted_today_count smallint;
  questions_json jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.is_ai_personalization_enabled(active_couple.id) then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  select coalesce(aiuqdu.submission_count, 0)
  into submitted_today_count
  from (
    select 1
  ) as fallback
  left join public.ai_user_question_daily_usage as aiuqdu
    on aiuqdu.couple_id = active_couple.id
    and aiuqdu.user_id = current_user_id
    and aiuqdu.context_date = current_couple_date;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', recent.id,
        'question_text', recent.question_text,
        'status', recent.status,
        'answer_text', recent.answer_text,
        'failure_code', recent.failure_code,
        'created_at', recent.created_at,
        'answered_at', recent.answered_at
      )
      order by recent.created_at desc, recent.id desc
    ),
    '[]'::jsonb
  )
  into questions_json
  from (
    select aiuq.*
    from public.ai_user_questions as aiuq
    where aiuq.couple_id = active_couple.id
      and aiuq.requester_user_id = current_user_id
    order by aiuq.created_at desc, aiuq.id desc
    limit 30
  ) as recent;

  return jsonb_build_object(
    'daily_limit', 3,
    'remaining_count', greatest(0, 3 - submitted_today_count),
    'questions', questions_json
  );
end;
$$;

create or replace function public.delete_my_ai_user_question(
  requested_question_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_question_id is null then
    perform private.raise_app_error('invalid_ai_user_question');
  end if;

  delete from public.ai_user_questions
  where id = requested_question_id
    and requester_user_id = current_user_id;

  return found;
end;
$$;

revoke execute on function public.submit_ai_user_question(text)
  from public, anon;
revoke execute on function public.get_my_ai_user_questions()
  from public, anon;
revoke execute on function public.delete_my_ai_user_question(uuid)
  from public, anon;
grant execute on function public.submit_ai_user_question(text)
  to authenticated;
grant execute on function public.get_my_ai_user_questions()
  to authenticated;
grant execute on function public.delete_my_ai_user_question(uuid)
  to authenticated;

create or replace function private.get_ai_user_personalization_context(
  target_couple_id uuid,
  target_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  memories_json jsonb;
  recent_questions_json jsonb;
begin
  select c.*
  into target_couple
  from public.couples as c
  where c.id = target_couple_id
    and c.status = 'active'
    and target_user_id in (c.user_a_id, c.user_b_id);

  if not found then
    perform private.raise_app_error('invalid_ai_personalization_context');
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'subject', case
          when aim.scope = 'couple' then 'couple'
          when aim.subject_user_id = target_user_id then 'me'
          else 'partner'
        end,
        'kind', aim.kind,
        'learning_domain', aim.learning_domain,
        'statement', aim.statement,
        'confidence', aim.confidence
      )
      order by aim.updated_at desc, aim.id
    ),
    '[]'::jsonb
  )
  into memories_json
  from public.ai_memories as aim
  where aim.couple_id = target_couple_id
    and aim.state = 'active';

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_text', recent.question_text,
        'answers', case
          when recent.source_type = 'daily' then (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'subject', case
                    when dqa.user_id = target_user_id then 'me'
                    else 'partner'
                  end,
                  'text', dqa.answer_text
                )
                order by case
                  when dqa.user_id = target_user_id then 1
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
                  'subject', case
                    when aifqa.user_id = target_user_id then 'me'
                    else 'partner'
                  end,
                  'text', aifqa.answer_text
                )
                order by case
                  when aifqa.user_id = target_user_id then 1
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
  into recent_questions_json
  from (
    select *
    from (
      select
        'daily'::text as source_type,
        dq.id as instance_id,
        greatest(dq.updated_at, dq.created_at) as completed_at,
        q.question_text
      from public.daily_questions as dq
      join public.questions as q on q.id = dq.question_id
      where dq.couple_id = target_couple_id
        and dq.status = 'completed'

      union all

      select
        'focused'::text,
        aifq.id,
        greatest(aifq.updated_at, aifq.created_at),
        q.question_text
      from public.ai_focused_questions as aifq
      join public.questions as q on q.id = aifq.question_id
      where aifq.couple_id = target_couple_id
        and aifq.status = 'completed'
    ) as completed_questions
    order by completed_at desc, instance_id
    limit 6
  ) as recent;

  return jsonb_build_object(
    'confirmed_memories', memories_json,
    'recent_completed_questions', recent_questions_json
  );
end;
$$;

revoke execute on function
  private.get_ai_user_personalization_context(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.get_ai_direct_question_job_context(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_job public.ai_processing_jobs%rowtype;
  target_question public.ai_user_questions%rowtype;
  personalization_context jsonb;
begin
  if requested_job_id is null then
    perform private.raise_app_error('invalid_ai_direct_question_context');
  end if;

  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id
  for update;

  if not found
    or target_job.job_type <> 'answer_user_question'
    or target_job.status <> 'processing'
    or target_job.user_question_id is null
    or target_job.daily_question_id is not null
    or target_job.focused_question_id is not null
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.is_ai_personalization_enabled(target_job.couple_id)
  then
    perform private.raise_app_error('invalid_ai_direct_question_context');
  end if;

  select aiuq.*
  into target_question
  from public.ai_user_questions as aiuq
  where aiuq.id = target_job.user_question_id
    and aiuq.couple_id = target_job.couple_id
    and aiuq.status = 'processing';

  if not found then
    perform private.raise_app_error('invalid_ai_direct_question_context');
  end if;

  personalization_context :=
    private.get_ai_user_personalization_context(
      target_job.couple_id,
      target_question.requester_user_id
    );

  return jsonb_build_object(
    'question_text', target_question.question_text,
    'confirmed_memories',
      personalization_context->'confirmed_memories',
    'recent_completed_questions',
      personalization_context->'recent_completed_questions'
  );
end;
$$;

create or replace function public.get_ai_proactive_suggestion_context(
  requested_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  current_couple_date date;
  current_local_hour integer;
  has_card_today boolean;
  personalization_context jsonb;
begin
  if requested_user_id is null then
    perform private.raise_app_error('invalid_ai_proactive_context');
  end if;

  select c.*
  into active_couple
  from public.couples as c
  where c.status = 'active'
    and requested_user_id in (c.user_a_id, c.user_b_id)
  order by c.created_at desc
  limit 1;

  if not found
    or not private.is_ai_personalization_enabled(active_couple.id)
  then
    perform private.raise_app_error('ai_personalization_not_ready');
  end if;

  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );
  current_local_hour := extract(
    hour from now() at time zone active_couple.timezone
  )::integer;

  select exists (
    select 1
    from public.story_loop_cards as slc
    where slc.couple_id = active_couple.id
      and slc.couple_date = current_couple_date
      and slc.author_user_id = requested_user_id
  )
  into has_card_today;

  personalization_context :=
    private.get_ai_user_personalization_context(
      active_couple.id,
      requested_user_id
    );

  return jsonb_build_object(
    'local_date', current_couple_date,
    'local_hour', current_local_hour,
    'timezone', active_couple.timezone,
    'has_card_today', has_card_today,
    'confirmed_memories',
      personalization_context->'confirmed_memories',
    'recent_completed_questions',
      personalization_context->'recent_completed_questions'
  );
end;
$$;

revoke execute on function public.get_ai_direct_question_job_context(uuid)
  from public, anon, authenticated;
revoke execute on function public.get_ai_proactive_suggestion_context(uuid)
  from public, anon, authenticated;
grant execute on function public.get_ai_direct_question_job_context(uuid)
  to service_role;
grant execute on function public.get_ai_proactive_suggestion_context(uuid)
  to service_role;

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
  target_couple record;
  waiting_loop record;
begin
  if normalized_worker is null
    or char_length(normalized_worker) not between 1 and 120
  then
    perform private.raise_app_error('invalid_ai_worker');
  end if;

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

  for waiting_loop in
    select dsl.couple_id, dsl.id
    from public.daily_story_loops as dsl
    where dsl.status = 'question_preparing'
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.story_loop_id = dsl.id
      )
    order by dsl.couple_date, dsl.created_at, dsl.id
  loop
    perform private.ensure_ai_question_job_for_story_loop(
      waiting_loop.couple_id,
      waiting_loop.id
    );
  end loop;

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
          aipj.job_type not in (
            'generate_personalized_question',
            'answer_user_question'
          )
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
          aipj.focused_question_id,
          aipj.user_question_id
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

revoke execute on function public.claim_ai_processing_jobs(text, integer)
  from public, anon, authenticated;
grant execute on function public.claim_ai_processing_jobs(text, integer)
  to service_role;

alter function public.start_ai_processing_run(
  uuid,
  text,
  text,
  text
) rename to start_ai_processing_run_before_direct_v12;

revoke execute on function public.start_ai_processing_run_before_direct_v12(
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
  normalized_provider text := btrim(requested_provider);
  normalized_model text := btrim(requested_model);
  normalized_prompt_version text := btrim(requested_prompt_version);
  target_job public.ai_processing_jobs%rowtype;
  target_question public.ai_user_questions%rowtype;
  existing_run_id uuid;
  created_run_id uuid;
begin
  select aipj.*
  into target_job
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id;

  if not found or target_job.job_type <> 'answer_user_question' then
    return public.start_ai_processing_run_before_direct_v12(
      requested_job_id,
      requested_provider,
      requested_model,
      requested_prompt_version
    );
  end if;

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
    or target_job.job_type <> 'answer_user_question'
    or target_job.user_question_id is null
    or target_job.daily_question_id is not null
    or target_job.focused_question_id is not null
    or target_job.claimed_by is null
    or target_job.lease_expires_at is null
    or target_job.lease_expires_at <= now()
    or not private.is_ai_personalization_enabled(target_job.couple_id)
  then
    perform private.raise_app_error('invalid_ai_run_job');
  end if;

  select aiuq.*
  into target_question
  from public.ai_user_questions as aiuq
  where aiuq.id = target_job.user_question_id
    and aiuq.couple_id = target_job.couple_id
    and aiuq.status = 'processing';

  if not found then
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

  insert into public.ai_runs (
    job_id,
    couple_id,
    user_question_id,
    task,
    provider,
    model,
    prompt_version,
    input_answer_ids
  )
  values (
    target_job.id,
    target_job.couple_id,
    target_job.user_question_id,
    target_job.job_type,
    normalized_provider,
    normalized_model,
    normalized_prompt_version,
    '{}'::uuid[]
  )
  returning id into created_run_id;

  return created_run_id;
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
) rename to succeed_ai_processing_run_before_direct_v12;

revoke execute on function public.succeed_ai_processing_run_before_direct_v12(
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
  target_job public.ai_processing_jobs%rowtype;
  target_question public.ai_user_questions%rowtype;
  normalized_answer text;
begin
  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not found or target_run.task <> 'answer_user_question' then
    return public.succeed_ai_processing_run_before_direct_v12(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );
  end if;

  normalized_answer := btrim(requested_output->>'answer_text');

  if requested_output is null
    or jsonb_typeof(requested_output) <> 'object'
    or normalized_answer is null
    or char_length(normalized_answer) not between 1 and 400
    or private.ai_question_contains_blocked_topic(normalized_answer)
    or requested_input_token_count is not null
      and requested_input_token_count < 0
    or requested_output_token_count is not null
      and requested_output_token_count < 0
    or requested_latency_ms is not null
      and requested_latency_ms < 0
  then
    perform private.raise_app_error('invalid_ai_direct_question_output');
  end if;

  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id
  for update;

  if not found
    or target_run.status <> 'started'
    or target_run.job_id is null
    or target_run.user_question_id is null
    or target_run.daily_question_id is not null
    or target_run.focused_question_id is not null
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
    or target_job.job_type <> 'answer_user_question'
    or target_job.user_question_id <> target_run.user_question_id
    or not private.is_ai_personalization_enabled(target_job.couple_id)
  then
    return false;
  end if;

  select aiuq.*
  into target_question
  from public.ai_user_questions as aiuq
  where aiuq.id = target_run.user_question_id
    and aiuq.couple_id = target_run.couple_id
    and aiuq.status = 'processing'
  for update;

  if not found then
    return false;
  end if;

  update public.ai_user_questions
  set
    status = 'completed',
    answer_text = normalized_answer,
    failure_code = null,
    answered_at = now()
  where id = target_question.id;

  update public.ai_runs
  set
    status = 'succeeded',
    input_token_count = requested_input_token_count,
    output_token_count = requested_output_token_count,
    latency_ms = requested_latency_ms,
    safety_status = 'passed',
    error_code = null,
    provider_http_status = null,
    provider_error_status = null,
    provider_error_detail = null,
    provider_retry_after_ms = null,
    completed_at = now()
  where id = target_run.id;

  update public.ai_processing_jobs
  set
    status = 'succeeded',
    completed_at = now(),
    lease_expires_at = null,
    last_error = null
  where id = target_job.id
    and status = 'processing';

  return found;
end;
$$;

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
