create table public.ai_focused_questions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  status text not null default 'answered_by_one',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_focused_questions_couple_question_unique
    unique (couple_id, question_id),
  constraint ai_focused_questions_status_check
    check (status in ('answered_by_one', 'completed'))
);

create index ai_focused_questions_couple_status_idx
  on public.ai_focused_questions (couple_id, status, updated_at desc);

alter table public.ai_focused_questions enable row level security;

create trigger ai_focused_questions_set_updated_at
  before update on public.ai_focused_questions
  for each row
  execute function public.set_updated_at();

create table public.ai_focused_question_answers (
  id uuid primary key default gen_random_uuid(),
  focused_question_id uuid not null
    references public.ai_focused_questions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  answer_text text not null,
  answered_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_focused_question_answers_question_user_unique
    unique (focused_question_id, user_id),
  constraint ai_focused_question_answers_text_length
    check (char_length(btrim(answer_text)) between 1 and 500)
);

create index ai_focused_question_answers_user_idx
  on public.ai_focused_question_answers (user_id, updated_at desc);

alter table public.ai_focused_question_answers enable row level security;

create trigger ai_focused_question_answers_set_updated_at
  before update on public.ai_focused_question_answers
  for each row
  execute function public.set_updated_at();

create table public.ai_focused_memory_evidence (
  memory_id uuid not null references public.ai_memories(id) on delete cascade,
  answer_id uuid not null
    references public.ai_focused_question_answers(id) on delete cascade,
  relevance numeric(4, 3) not null default 1,
  created_at timestamptz not null default now(),

  primary key (memory_id, answer_id),
  constraint ai_focused_memory_evidence_relevance_check
    check (relevance between 0 and 1)
);

create index ai_focused_memory_evidence_answer_idx
  on public.ai_focused_memory_evidence (answer_id);

alter table public.ai_focused_memory_evidence enable row level security;

revoke all on table public.ai_focused_questions
  from public, anon, authenticated;
revoke all on table public.ai_focused_question_answers
  from public, anon, authenticated;
revoke all on table public.ai_focused_memory_evidence
  from public, anon, authenticated;

grant all on table public.ai_focused_questions to service_role;
grant all on table public.ai_focused_question_answers to service_role;
grant all on table public.ai_focused_memory_evidence to service_role;

alter table public.ai_processing_jobs
  add column focused_question_id uuid
    references public.ai_focused_questions(id) on delete cascade;

alter table public.ai_runs
  add column focused_question_id uuid
    references public.ai_focused_questions(id) on delete set null;

alter table public.ai_processing_jobs
  add constraint ai_processing_jobs_question_source_check
    check (
      (
        job_type = 'rebuild_profile'
        and daily_question_id is null
        and focused_question_id is null
      )
      or (
        job_type <> 'rebuild_profile'
        and num_nonnulls(daily_question_id, focused_question_id) = 1
      )
    );

alter table public.ai_runs
  add constraint ai_runs_question_source_check
    check (num_nonnulls(daily_question_id, focused_question_id) = 1);

create index ai_processing_jobs_focused_question_idx
  on public.ai_processing_jobs (focused_question_id)
  where focused_question_id is not null;

create index ai_runs_focused_question_idx
  on public.ai_runs (focused_question_id)
  where focused_question_id is not null;

create or replace function private.completed_ai_foundation_question_ids(
  target_couple_id uuid,
  target_curriculum_version integer
)
returns table (question_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct completed.question_id
  from (
    select dq.question_id
    from public.daily_questions as dq
    join public.questions as q on q.id = dq.question_id
    where dq.couple_id = target_couple_id
      and dq.status = 'completed'
      and q.curriculum_version = target_curriculum_version

    union

    select aifq.question_id
    from public.ai_focused_questions as aifq
    join public.questions as q on q.id = aifq.question_id
    where aifq.couple_id = target_couple_id
      and aifq.status = 'completed'
      and q.curriculum_version = target_curriculum_version
  ) as completed;
$$;

create or replace function private.has_ai_foundation_answer(
  target_couple_id uuid,
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
    join public.daily_question_answers as dqa
      on dqa.daily_question_id = dq.id
    where dq.couple_id = target_couple_id
      and dq.question_id = target_question_id
      and dqa.user_id = target_user_id
  )
  or exists (
    select 1
    from public.ai_focused_questions as aifq
    join public.ai_focused_question_answers as aifqa
      on aifqa.focused_question_id = aifq.id
    where aifq.couple_id = target_couple_id
      and aifq.question_id = target_question_id
      and aifqa.user_id = target_user_id
  );
$$;

create or replace function private.is_ai_foundation_question_completed(
  target_couple_id uuid,
  target_question_id uuid
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
    where dq.couple_id = target_couple_id
      and dq.question_id = target_question_id
      and dq.status = 'completed'
  )
  or exists (
    select 1
    from public.ai_focused_questions as aifq
    where aifq.couple_id = target_couple_id
      and aifq.question_id = target_question_id
      and aifq.status = 'completed'
  );
$$;

create or replace function private.promote_ai_focused_question_to_daily(
  target_daily_question_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_daily_question public.daily_questions%rowtype;
  target_focused_question public.ai_focused_questions%rowtype;
  saved_answer_count integer := 0;
  next_status text;
begin
  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.id = target_daily_question_id
  for update;

  if not found then
    perform private.raise_app_error('invalid_daily_question');
  end if;

  select aifq.*
  into target_focused_question
  from public.ai_focused_questions as aifq
  where aifq.couple_id = target_daily_question.couple_id
    and aifq.question_id = target_daily_question.question_id
    and aifq.status = 'answered_by_one'
  for update;

  if found then
    insert into public.daily_question_answers (
      daily_question_id,
      user_id,
      answer_text,
      answered_at,
      updated_at
    )
    select
      target_daily_question.id,
      aifqa.user_id,
      aifqa.answer_text,
      aifqa.answered_at,
      aifqa.updated_at
    from public.ai_focused_question_answers as aifqa
    where aifqa.focused_question_id = target_focused_question.id
    on conflict on constraint daily_question_answers_daily_question_user_unique
    do nothing;

    delete from public.ai_focused_questions as aifq
    where aifq.id = target_focused_question.id;
  end if;

  select count(*)::integer
  into saved_answer_count
  from public.daily_question_answers as dqa
  where dqa.daily_question_id = target_daily_question.id;

  next_status := case
    when saved_answer_count >= 2 then 'completed'
    when saved_answer_count = 1 then 'answered_by_one'
    else 'pending'
  end;

  update public.daily_questions as dq
  set status = next_status
  where dq.id = target_daily_question.id;

  if saved_answer_count > 0 then
    update public.daily_story_loops as dsl
    set status = next_status
    where dsl.id = target_daily_question.story_loop_id;
  end if;

  return saved_answer_count;
end;
$$;

revoke execute on function private.completed_ai_foundation_question_ids(
  uuid,
  integer
) from public, anon, authenticated;
revoke execute on function private.has_ai_foundation_answer(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke execute on function private.is_ai_foundation_question_completed(
  uuid,
  uuid
) from public, anon, authenticated;
revoke execute on function private.promote_ai_focused_question_to_daily(uuid)
  from public, anon, authenticated;

create or replace function public.get_ai_focused_question_flow()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  partner_user_id uuid;
  my_answered_count integer;
  partner_answered_count integer;
  couple_completed_count integer;
  selected_question public.questions%rowtype;
  selected_question_id uuid;
  selected_recommendation_id uuid;
  flow_status text;
  question_json jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  if not private.has_ai_feature_entitlement(
    active_couple.id,
    'focused_questions'
  ) then
    perform private.raise_app_error('ai_focused_questions_locked');
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

  partner_user_id := case
    when active_couple.user_a_id = current_user_id
      then active_couple.user_b_id
    else active_couple.user_a_id
  end;

  select count(*)::integer
  into my_answered_count
  from public.questions as q
  where q.curriculum_version = active_curriculum.version
    and private.has_ai_foundation_answer(
      active_couple.id,
      q.id,
      current_user_id
    );

  select count(*)::integer
  into partner_answered_count
  from public.questions as q
  where q.curriculum_version = active_curriculum.version
    and private.has_ai_foundation_answer(
      active_couple.id,
      q.id,
      partner_user_id
    );

  select count(*)::integer
  into couple_completed_count
  from private.completed_ai_foundation_question_ids(
    active_couple.id,
    active_curriculum.version
  );

  if my_answered_count < active_curriculum.question_count then
    select aiqr.id, aiqr.question_id
    into selected_recommendation_id, selected_question_id
    from public.ai_question_recommendations as aiqr
    join public.questions as q on q.id = aiqr.question_id
    where aiqr.couple_id = active_couple.id
      and aiqr.status = 'pending'
      and aiqr.expires_at > now()
      and q.curriculum_version = active_curriculum.version
      and q.is_active
      and not private.has_ai_foundation_answer(
        active_couple.id,
        q.id,
        current_user_id
      )
    order by aiqr.created_at desc, aiqr.id
    limit 1;

    if selected_question_id is not null then
      select q.*
      into selected_question
      from public.questions as q
      where q.id = selected_question_id;
    end if;

    if selected_question.id is null then
      select q.*
      into selected_question
      from public.questions as q
      where q.curriculum_version = active_curriculum.version
        and q.is_active
        and not private.has_ai_foundation_answer(
          active_couple.id,
          q.id,
          current_user_id
        )
      order by q.curriculum_position, q.id
      limit 1;
    end if;
  end if;

  flow_status := case
    when couple_completed_count >= active_curriculum.question_count
      then 'completed'
    when my_answered_count >= active_curriculum.question_count
      then 'waiting_partner'
    else 'answering'
  end;

  question_json := case
    when selected_question.id is null then null
    else jsonb_build_object(
      'question_id', selected_question.id,
      'question_key', selected_question.question_key,
      'question_text', selected_question.question_text,
      'learning_domain', selected_question.learning_domain,
      'question_depth', selected_question.question_depth,
      'curriculum_position', selected_question.curriculum_position,
      'partner_answered', private.has_ai_foundation_answer(
        active_couple.id,
        selected_question.id,
        partner_user_id
      )
    )
  end;

  return jsonb_build_object(
    'status', flow_status,
    'progress', jsonb_build_object(
      'curriculum_version', active_curriculum.version,
      'my_answered_count', my_answered_count,
      'partner_answered_count', partner_answered_count,
      'couple_completed_count', couple_completed_count,
      'total_count', active_curriculum.question_count
    ),
    'question', question_json
  );
end;
$$;

create or replace function public.unlock_ai_focused_questions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  insert into public.ai_feature_entitlements (
    couple_id,
    feature_key,
    source,
    is_enabled,
    granted_at,
    expires_at
  )
  values (
    active_couple.id,
    'focused_questions',
    'in_app_unlock',
    true,
    now(),
    null
  )
  on conflict (couple_id, feature_key) do update
  set
    source = excluded.source,
    is_enabled = true,
    granted_at = excluded.granted_at,
    expires_at = null;

  return public.get_ai_focused_question_flow();
end;
$$;

create or replace function public.submit_ai_focused_question_answer(
  requested_question_id uuid,
  requested_answer_text text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  active_curriculum public.ai_question_curricula%rowtype;
  target_question public.questions%rowtype;
  target_daily_question public.daily_questions%rowtype;
  target_focused_question public.ai_focused_questions%rowtype;
  normalized_answer text := btrim(requested_answer_text);
  saved_answer_count integer;
  next_status text;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_question_id is null then
    perform private.raise_app_error('invalid_daily_question');
  end if;

  if normalized_answer is null or char_length(normalized_answer) = 0 then
    perform private.raise_app_error('answer_required');
  end if;

  if char_length(normalized_answer) > 500 then
    perform private.raise_app_error('answer_too_long');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  if not private.has_ai_feature_entitlement(
    active_couple.id,
    'focused_questions'
  ) then
    perform private.raise_app_error('ai_focused_questions_locked');
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

  select q.*
  into target_question
  from public.questions as q
  where q.id = requested_question_id
    and q.curriculum_version = active_curriculum.version
    and q.source = 'curated'
    and q.is_active;

  if not found then
    perform private.raise_app_error('invalid_daily_question');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_focused_question_answer'),
    hashtext(active_couple.id::text || ':' || target_question.id::text)
  );

  if private.has_ai_foundation_answer(
    active_couple.id,
    target_question.id,
    current_user_id
  ) then
    return public.get_ai_focused_question_flow();
  end if;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = active_couple.id
    and dq.question_id = target_question.id
    and dq.status <> 'completed'
  order by dq.assigned_date desc, dq.created_at desc, dq.id
  limit 1
  for update;

  if found then
    perform private.promote_ai_focused_question_to_daily(
      target_daily_question.id
    );

    insert into public.daily_question_answers (
      daily_question_id,
      user_id,
      answer_text
    )
    values (
      target_daily_question.id,
      current_user_id,
      normalized_answer
    )
    on conflict on constraint daily_question_answers_daily_question_user_unique
    do nothing;

    select count(*)::integer
    into saved_answer_count
    from public.daily_question_answers as dqa
    where dqa.daily_question_id = target_daily_question.id;

    next_status := case
      when saved_answer_count >= 2 then 'completed'
      else 'answered_by_one'
    end;

    update public.daily_questions as dq
    set status = next_status
    where dq.id = target_daily_question.id;

    update public.daily_story_loops as dsl
    set status = next_status
    where dsl.id = target_daily_question.story_loop_id;
  else
    insert into public.ai_focused_questions (
      couple_id,
      question_id,
      status
    )
    values (
      active_couple.id,
      target_question.id,
      'answered_by_one'
    )
    on conflict on constraint ai_focused_questions_couple_question_unique
    do nothing;

    select aifq.*
    into target_focused_question
    from public.ai_focused_questions as aifq
    where aifq.couple_id = active_couple.id
      and aifq.question_id = target_question.id
    for update;

    if target_focused_question.status = 'completed' then
      perform private.raise_app_error('question_not_ready');
    end if;

    insert into public.ai_focused_question_answers (
      focused_question_id,
      user_id,
      answer_text
    )
    values (
      target_focused_question.id,
      current_user_id,
      normalized_answer
    )
    on conflict on constraint
      ai_focused_question_answers_question_user_unique
    do nothing;

    select count(*)::integer
    into saved_answer_count
    from public.ai_focused_question_answers as aifqa
    where aifqa.focused_question_id = target_focused_question.id
      and aifqa.user_id in (
        active_couple.user_a_id,
        active_couple.user_b_id
      );

    next_status := case
      when saved_answer_count >= 2 then 'completed'
      else 'answered_by_one'
    end;

    update public.ai_focused_questions as aifq
    set status = next_status
    where aifq.id = target_focused_question.id;
  end if;

  return public.get_ai_focused_question_flow();
end;
$$;

revoke execute on function public.get_ai_focused_question_flow()
  from public, anon;
revoke execute on function public.unlock_ai_focused_questions()
  from public, anon;
revoke execute on function public.submit_ai_focused_question_answer(uuid, text)
  from public, anon;

grant execute on function public.get_ai_focused_question_flow()
  to authenticated;
grant execute on function public.unlock_ai_focused_questions()
  to authenticated;
grant execute on function public.submit_ai_focused_question_answer(uuid, text)
  to authenticated;
