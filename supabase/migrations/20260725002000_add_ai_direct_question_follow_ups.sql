create or replace function private.normalize_ai_question_text(
  requested_text text
)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select regexp_replace(
    lower(regexp_replace(btrim(requested_text), '[[:space:]]+', ' ', 'g')),
    '[?!]+$',
    ''
  );
$$;

create or replace function private.is_safe_ai_direct_follow_up_question(
  requested_question text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select
    coalesce(char_length(btrim(requested_question)) between 1 and 300, false)
    and right(btrim(requested_question), 1) = '?'
    and not private.ai_question_contains_blocked_topic(requested_question)
    and coalesce(requested_question, '') !~* (
      '(^|[[:space:]])(너는|넌|네가|니가|당신은)([[:space:]]|$|[!?,'']+)'
      || '|(상대|상대방|파트너)(은|는|이|가)'
      || '|파트너[[:space:]]*[ab]'
      || '|partner[_[:space:]-]?[ab]'
      || '|사용자[[:space:]]*[ab]'
      || '|(첫|두)[[:space:]]*번째[[:space:]]*(사용자|사람|파트너)'
      || '|(숨은|진짜)[[:space:]]*(의도|마음|속마음)'
      || '|성격[[:space:]]*(판단|분석|진단)'
      || '|관계[[:space:]]*(지속|종료|이별)[[:space:]]*(판단|결정|권유)'
    );
$$;

alter table public.ai_user_questions
  add column result_kind text;

update public.ai_user_questions
set result_kind = 'answered'
where status = 'completed'
  and result_kind is null;

alter table public.ai_user_questions
  add constraint ai_user_questions_result_kind_check
    check (
      (
        status = 'completed'
        and result_kind in ('answered', 'insufficient')
      )
      or (
        status <> 'completed'
        and result_kind is null
      )
    );

create table public.ai_user_question_follow_ups (
  id uuid primary key default gen_random_uuid(),
  user_question_id uuid unique
    references public.ai_user_questions(id) on delete cascade,
  couple_id uuid not null references public.couples(id) on delete cascade,
  requester_user_id uuid references auth.users(id) on delete set null,
  source_run_id uuid references public.ai_runs(id) on delete set null,
  shared_question_id uuid unique
    references public.questions(id) on delete cascade,
  question_key text not null,
  question_text text not null,
  category text not null,
  mood text,
  rationale text not null,
  status text not null default 'pending',
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ai_user_question_follow_ups_key_check
    check (
      question_key ~ '^direct_follow_up_[a-z0-9_]+_[a-z0-9]{8}$'
      and char_length(question_key) between 1 and 120
    ),
  constraint ai_user_question_follow_ups_question_check
    check (private.is_safe_ai_direct_follow_up_question(question_text)),
  constraint ai_user_question_follow_ups_category_check
    check (char_length(btrim(category)) between 1 and 100),
  constraint ai_user_question_follow_ups_mood_check
    check (
      mood is null
      or char_length(btrim(mood)) between 1 and 100
    ),
  constraint ai_user_question_follow_ups_rationale_check
    check (char_length(btrim(rationale)) between 1 and 500),
  constraint ai_user_question_follow_ups_status_check
    check (status in ('pending', 'approved', 'dismissed')),
  constraint ai_user_question_follow_ups_lifecycle_check
    check (
      (
        status = 'pending'
        and user_question_id is not null
        and requester_user_id is not null
        and shared_question_id is null
        and decided_at is null
      )
      or (
        status = 'approved'
        and shared_question_id is not null
        and decided_at is not null
      )
      or (
        status = 'dismissed'
        and user_question_id is not null
        and shared_question_id is null
        and decided_at is not null
      )
    )
);

create index ai_user_question_follow_ups_couple_status_idx
  on public.ai_user_question_follow_ups (
    couple_id,
    status,
    created_at,
    id
  );

alter table public.ai_user_question_follow_ups enable row level security;

create trigger ai_user_question_follow_ups_set_updated_at
  before update on public.ai_user_question_follow_ups
  for each row
  execute function public.set_updated_at();

revoke all on table public.ai_user_question_follow_ups
  from public, anon, authenticated;
grant all on table public.ai_user_question_follow_ups to service_role;

alter table public.questions
  add column approved_follow_up_id uuid
    references public.ai_user_question_follow_ups(id) on delete set null;

create unique index questions_approved_follow_up_unique
  on public.questions (approved_follow_up_id)
  where approved_follow_up_id is not null;

alter table public.questions
  drop constraint questions_ai_provenance_check;

alter table public.questions
  add constraint questions_ai_provenance_check
    check (
      (
        source = 'curated'
        and personalized_for_couple_id is null
        and generated_by_run_id is null
        and approved_follow_up_id is null
      )
      or (
        source = 'ai'
        and question_key is not null
        and (
          is_active = false
          or (
            personalized_for_couple_id is not null
            and num_nonnulls(
              generated_by_run_id,
              approved_follow_up_id
            ) = 1
          )
        )
      )
    );

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
      or num_nonnulls(
        new.generated_by_run_id,
        new.approved_follow_up_id
      ) <> 1
    )
  then
    new.is_active := false;
  end if;

  return new;
end;
$$;

alter table public.questions
  drop constraint questions_source_question_text_unique;

create unique index questions_curated_text_unique
  on public.questions (question_text)
  where source = 'curated';

create unique index questions_ai_couple_text_unique
  on public.questions (personalized_for_couple_id, question_text)
  where source = 'ai'
    and personalized_for_couple_id is not null;

alter table public.ai_question_recommendations
  alter column source_run_id drop not null,
  add column source_follow_up_id uuid
    references public.ai_user_question_follow_ups(id) on delete cascade;

alter table public.ai_question_recommendations
  add constraint ai_question_recommendations_source_check
    check (num_nonnulls(source_run_id, source_follow_up_id) = 1);

create unique index ai_question_recommendations_follow_up_unique
  on public.ai_question_recommendations (source_follow_up_id)
  where source_follow_up_id is not null;

create or replace function private.enforce_ai_question_queue_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pending_count integer;
  approved_follow_up_count integer;
begin
  if new.status <> 'pending' then
    return new;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(new.couple_id::text)
  );

  update public.ai_question_recommendations
  set status = 'expired'
  where couple_id = new.couple_id
    and status = 'pending'
    and expires_at <= now();

  select
    count(*)::integer,
    count(*) filter (
      where source_follow_up_id is not null
    )::integer
  into pending_count, approved_follow_up_count
  from public.ai_question_recommendations
  where couple_id = new.couple_id
    and status = 'pending';

  if new.source_follow_up_id is not null
    and approved_follow_up_count >= 2
  then
    perform private.raise_app_error('ai_follow_up_queue_full');
  end if;

  if pending_count >= 2 then
    update public.ai_question_recommendations
    set status = 'expired'
    where id in (
      select aiqr.id
      from public.ai_question_recommendations as aiqr
      where aiqr.couple_id = new.couple_id
        and aiqr.status = 'pending'
        and aiqr.source_follow_up_id is null
      order by aiqr.created_at, aiqr.id
      limit greatest(pending_count - 1, 0)
    );
  end if;

  select count(*)::integer
  into pending_count
  from public.ai_question_recommendations
  where couple_id = new.couple_id
    and status = 'pending';

  if pending_count >= 2 then
    if new.source_follow_up_id is not null then
      perform private.raise_app_error('ai_follow_up_queue_full');
    end if;
    new.status := 'expired';
  end if;

  update public.questions as q
  set is_active = false
  where q.id in (
    select aiqr.question_id
    from public.ai_question_recommendations as aiqr
    where aiqr.couple_id = new.couple_id
      and aiqr.status = 'expired'
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.question_id = aiqr.question_id
      )
  );

  if new.status = 'expired' then
    update public.questions
    set is_active = false
    where id = new.question_id
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.question_id = new.question_id
      );
  end if;

  return new;
end;
$$;

create trigger ai_question_recommendations_enforce_capacity
  before insert on public.ai_question_recommendations
  for each row
  execute function private.enforce_ai_question_queue_capacity();

create or replace function private.get_recent_ai_shared_question_texts(
  target_couple_id uuid,
  requested_limit integer default 30
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(recent.question_text order by recent.seen_at desc),
    '[]'::jsonb
  )
  from (
    select deduplicated.question_text, deduplicated.seen_at
    from (
      select distinct on (
        private.normalize_ai_question_text(candidates.question_text)
      )
        candidates.question_text,
        candidates.seen_at
      from (
        select q.question_text, greatest(dq.updated_at, dq.created_at) as seen_at
        from public.daily_questions as dq
        join public.questions as q on q.id = dq.question_id
        where dq.couple_id = target_couple_id

        union all

        select
          q.question_text,
          greatest(aifq.updated_at, aifq.created_at)
        from public.ai_focused_questions as aifq
        join public.questions as q on q.id = aifq.question_id
        where aifq.couple_id = target_couple_id

        union all

        select q.question_text, aiqr.created_at
        from public.ai_question_recommendations as aiqr
        join public.questions as q on q.id = aiqr.question_id
        where aiqr.couple_id = target_couple_id
          and aiqr.status = 'pending'

        union all

        select aiuqfu.question_text, aiuqfu.created_at
        from public.ai_user_question_follow_ups as aiuqfu
        where aiuqfu.couple_id = target_couple_id
          and aiuqfu.status in ('pending', 'approved')
      ) as candidates
      order by
        private.normalize_ai_question_text(candidates.question_text),
        candidates.seen_at desc
    ) as deduplicated
    order by deduplicated.seen_at desc
    limit greatest(1, least(coalesce(requested_limit, 30), 100))
  ) as recent;
$$;

alter function public.get_ai_direct_question_job_context(uuid)
  rename to get_ai_direct_question_job_context_before_follow_ups_v14;

revoke execute on function
  public.get_ai_direct_question_job_context_before_follow_ups_v14(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.get_ai_direct_question_job_context(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  base_context jsonb;
  target_couple_id uuid;
begin
  base_context :=
    public.get_ai_direct_question_job_context_before_follow_ups_v14(
      requested_job_id
    );

  select aipj.couple_id
  into target_couple_id
  from public.ai_processing_jobs as aipj
  where aipj.id = requested_job_id;

  return base_context || jsonb_build_object(
    'recent_shared_questions',
    private.get_recent_ai_shared_question_texts(target_couple_id)
  );
end;
$$;

revoke execute on function public.get_ai_direct_question_job_context(uuid)
  from public, anon, authenticated;
grant execute on function public.get_ai_direct_question_job_context(uuid)
  to service_role;

alter function public.succeed_ai_processing_run(
  uuid,
  jsonb,
  integer,
  integer,
  integer
) rename to succeed_ai_processing_run_before_direct_follow_ups_v14;

revoke execute on function
  public.succeed_ai_processing_run_before_direct_follow_ups_v14(
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
  normalized_status text;
  normalized_answer text;
  follow_up_output jsonb;
  normalized_question_key text;
  normalized_question_text text;
  normalized_category text;
  normalized_mood text;
  normalized_rationale text;
  candidate_is_valid boolean := false;
  completion_result boolean;
begin
  select air.*
  into target_run
  from public.ai_runs as air
  where air.id = requested_run_id;

  if not found or target_run.task <> 'answer_user_question' then
    return public.succeed_ai_processing_run_before_direct_follow_ups_v14(
      requested_run_id,
      requested_output,
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );
  end if;

  normalized_status := coalesce(
    nullif(btrim(requested_output->>'answer_status'), ''),
    'answered'
  );
  normalized_answer := btrim(requested_output->>'answer_text');

  if normalized_status not in ('answered', 'insufficient') then
    perform private.raise_app_error('invalid_ai_direct_question_output');
  end if;

  if normalized_status = 'insufficient'
    and jsonb_typeof(requested_output->'follow_up_question') = 'object'
  then
    follow_up_output := requested_output->'follow_up_question';
    normalized_question_key := btrim(
      follow_up_output->>'question_key'
    );
    normalized_question_text := btrim(
      follow_up_output->>'question_text'
    );
    normalized_category := btrim(follow_up_output->>'category');
    normalized_mood := nullif(btrim(follow_up_output->>'mood'), '');
    normalized_rationale := btrim(follow_up_output->>'rationale');

    candidate_is_valid :=
      normalized_question_key is not null
      and normalized_question_key
        ~ '^direct_follow_up_[a-z0-9_]+_[a-z0-9]{8}$'
      and char_length(normalized_question_key) between 1 and 120
      and private.is_safe_ai_direct_follow_up_question(
        normalized_question_text
      )
      and normalized_category is not null
      and char_length(normalized_category) between 1 and 100
      and (
        normalized_mood is null
        or char_length(normalized_mood) between 1 and 100
      )
      and normalized_rationale is not null
      and char_length(normalized_rationale) between 1 and 500;
  end if;

  completion_result :=
    public.succeed_ai_processing_run_before_direct_follow_ups_v14(
      requested_run_id,
      jsonb_build_object('answer_text', normalized_answer),
      requested_input_token_count,
      requested_output_token_count,
      requested_latency_ms
    );

  if completion_result is not true then
    return false;
  end if;

  update public.ai_user_questions
  set result_kind = normalized_status
  where id = target_run.user_question_id
    and status = 'completed';

  if candidate_is_valid then
    perform pg_advisory_xact_lock(
      hashtext('ai_direct_follow_up_candidate'),
      hashtext(target_run.couple_id::text)
    );

    if not exists (
      select 1
      from public.ai_user_question_follow_ups as aiuqfu
      where aiuqfu.couple_id = target_run.couple_id
        and aiuqfu.status in ('pending', 'approved')
        and private.normalize_ai_question_text(aiuqfu.question_text) =
          private.normalize_ai_question_text(normalized_question_text)
    )
    and not exists (
      select 1
      from public.questions as q
      where private.normalize_ai_question_text(q.question_text) =
          private.normalize_ai_question_text(normalized_question_text)
        and (
          q.personalized_for_couple_id = target_run.couple_id
          or exists (
            select 1
            from public.daily_questions as dq
            where dq.couple_id = target_run.couple_id
              and dq.question_id = q.id
          )
          or exists (
            select 1
            from public.ai_focused_questions as aifq
            where aifq.couple_id = target_run.couple_id
              and aifq.question_id = q.id
          )
        )
    )
    then
      begin
        insert into public.ai_user_question_follow_ups (
          user_question_id,
          couple_id,
          requester_user_id,
          source_run_id,
          question_key,
          question_text,
          category,
          mood,
          rationale
        )
        select
          aiuq.id,
          aiuq.couple_id,
          aiuq.requester_user_id,
          target_run.id,
          normalized_question_key,
          normalized_question_text,
          normalized_category,
          normalized_mood,
          normalized_rationale
        from public.ai_user_questions as aiuq
        where aiuq.id = target_run.user_question_id
          and aiuq.status = 'completed'
        on conflict (user_question_id) do nothing;
      exception
        when check_violation
          or unique_violation
          or foreign_key_violation
          or not_null_violation
          or string_data_right_truncation
        then
          null;
      end;
    end if;
  end if;

  return true;
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
        'result_kind', recent.result_kind,
        'answer_text', recent.answer_text,
        'failure_code', recent.failure_code,
        'created_at', recent.created_at,
        'answered_at', recent.answered_at,
        'follow_up', case
          when recent.follow_up_id is null then null
          else jsonb_build_object(
            'id', recent.follow_up_id,
            'question_text', recent.follow_up_question_text,
            'status', recent.follow_up_status,
            'shared_question_id', recent.shared_question_id
          )
        end
      )
      order by recent.created_at desc, recent.id desc
    ),
    '[]'::jsonb
  )
  into questions_json
  from (
    select
      aiuq.*,
      aiuqfu.id as follow_up_id,
      aiuqfu.question_text as follow_up_question_text,
      aiuqfu.status as follow_up_status,
      aiuqfu.shared_question_id
    from public.ai_user_questions as aiuq
    left join public.ai_user_question_follow_ups as aiuqfu
      on aiuqfu.user_question_id = aiuq.id
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

create or replace function public.decide_ai_user_question_follow_up(
  requested_question_id uuid,
  requested_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_decision text := lower(btrim(requested_decision));
  decided_status text := case lower(btrim(requested_decision))
    when 'approve' then 'approved'
    when 'dismiss' then 'dismissed'
  end;
  target_follow_up public.ai_user_question_follow_ups%rowtype;
  created_question_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_question_id is null
    or normalized_decision not in ('approve', 'dismiss')
  then
    perform private.raise_app_error('invalid_ai_follow_up_decision');
  end if;

  select aiuqfu.*
  into target_follow_up
  from public.ai_user_question_follow_ups as aiuqfu
  join public.ai_user_questions as aiuq
    on aiuq.id = aiuqfu.user_question_id
  where aiuq.id = requested_question_id
    and aiuq.requester_user_id = current_user_id
    and aiuq.couple_id = aiuqfu.couple_id
  for update of aiuqfu;

  if not found then
    perform private.raise_app_error('ai_follow_up_not_found');
  end if;

  if target_follow_up.status <> 'pending' then
    if target_follow_up.status = decided_status then
      return jsonb_build_object(
        'status', target_follow_up.status,
        'shared_question_id', target_follow_up.shared_question_id
      );
    end if;

    perform private.raise_app_error('ai_follow_up_already_decided');
  end if;

  if normalized_decision = 'dismiss' then
    update public.ai_user_question_follow_ups
    set
      status = 'dismissed',
      decided_at = now()
    where id = target_follow_up.id;

    return jsonb_build_object(
      'status', 'dismissed',
      'shared_question_id', null
    );
  end if;

  if not private.is_ai_personalization_enabled(target_follow_up.couple_id)
    or not private.is_safe_ai_direct_follow_up_question(
      target_follow_up.question_text
    )
  then
    perform private.raise_app_error('ai_follow_up_not_available');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(target_follow_up.couple_id::text)
  );

  if exists (
    select 1
    from public.questions as q
    where private.normalize_ai_question_text(q.question_text) =
        private.normalize_ai_question_text(target_follow_up.question_text)
      and (
        q.personalized_for_couple_id = target_follow_up.couple_id
        or exists (
          select 1
          from public.daily_questions as dq
          where dq.couple_id = target_follow_up.couple_id
            and dq.question_id = q.id
        )
        or exists (
          select 1
          from public.ai_focused_questions as aifq
          where aifq.couple_id = target_follow_up.couple_id
            and aifq.question_id = q.id
        )
      )
  ) then
    perform private.raise_app_error('ai_follow_up_duplicate');
  end if;

  insert into public.questions (
    source,
    question_key,
    question_text,
    category,
    mood,
    is_active,
    personalized_for_couple_id,
    generated_by_run_id,
    approved_follow_up_id
  )
  values (
    'ai',
    'direct_follow_up_' || replace(target_follow_up.id::text, '-', ''),
    target_follow_up.question_text,
    target_follow_up.category,
    target_follow_up.mood,
    true,
    target_follow_up.couple_id,
    null,
    target_follow_up.id
  )
  returning id into created_question_id;

  insert into public.ai_question_recommendations (
    couple_id,
    question_id,
    source_run_id,
    source_follow_up_id,
    reason
  )
  values (
    target_follow_up.couple_id,
    created_question_id,
    null,
    target_follow_up.id,
    target_follow_up.rationale
  );

  update public.ai_user_question_follow_ups
  set
    status = 'approved',
    shared_question_id = created_question_id,
    decided_at = now()
  where id = target_follow_up.id;

  perform private.attach_pending_ai_question_to_waiting_loop(
    target_follow_up.couple_id
  );

  return jsonb_build_object(
    'status', 'approved',
    'shared_question_id', created_question_id
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

  update public.ai_user_question_follow_ups as aiuqfu
  set user_question_id = null
  from public.ai_user_questions as aiuq
  where aiuq.id = requested_question_id
    and aiuq.requester_user_id = current_user_id
    and aiuqfu.user_question_id = aiuq.id
    and aiuqfu.status = 'approved';

  delete from public.ai_user_questions
  where id = requested_question_id
    and requester_user_id = current_user_id;

  return found;
end;
$$;

create or replace function private.assign_pending_ai_question_to_story_loop(
  target_couple public.couples,
  target_story_loop public.daily_story_loops
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  expected_job_type text;
  selected_recommendation_id uuid;
  selected_question_id uuid;
  target_daily_question public.daily_questions%rowtype;
begin
  expected_job_type := private.ai_generated_question_job_type(
    target_couple.id
  );

  perform pg_advisory_xact_lock(
    hashtext('ai_question_recommendation'),
    hashtext(target_couple.id::text)
  );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_runs as air, public.questions as q
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and air.id = aiqr.source_run_id
    and q.id = aiqr.question_id
    and (
      aiqr.expires_at <= now()
      or expected_job_type is null
      or air.task <> expected_job_type
      or q.source <> 'ai'
      or q.personalized_for_couple_id <> target_couple.id
      or not q.is_active
      or exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_couple.id
          and used_dq.question_id = q.id
      )
    );

  update public.ai_question_recommendations as aiqr
  set status = 'expired'
  from public.ai_user_question_follow_ups as aiuqfu,
    public.questions as q
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and aiuqfu.id = aiqr.source_follow_up_id
    and q.id = aiqr.question_id
    and (
      aiqr.expires_at <= now()
      or aiuqfu.status <> 'approved'
      or aiuqfu.shared_question_id <> q.id
      or q.source <> 'ai'
      or q.personalized_for_couple_id <> target_couple.id
      or not q.is_active
      or exists (
        select 1
        from public.daily_questions as used_dq
        where used_dq.couple_id = target_couple.id
          and used_dq.question_id = q.id
      )
    );

  update public.questions as q
  set is_active = false
  where q.id in (
    select aiqr.question_id
    from public.ai_question_recommendations as aiqr
    where aiqr.couple_id = target_couple.id
      and aiqr.status = 'expired'
      and not exists (
        select 1
        from public.daily_questions as dq
        where dq.question_id = aiqr.question_id
      )
  );

  select aiqr.id, aiqr.question_id
  into selected_recommendation_id, selected_question_id
  from public.ai_question_recommendations as aiqr
  join public.questions as q on q.id = aiqr.question_id
  left join public.ai_runs as air on air.id = aiqr.source_run_id
  left join public.ai_user_question_follow_ups as aiuqfu
    on aiuqfu.id = aiqr.source_follow_up_id
  where aiqr.couple_id = target_couple.id
    and aiqr.status = 'pending'
    and aiqr.expires_at > now()
    and q.source = 'ai'
    and q.personalized_for_couple_id = target_couple.id
    and q.is_active
    and (
      (
        aiqr.source_follow_up_id is not null
        and aiuqfu.status = 'approved'
        and aiuqfu.shared_question_id = q.id
      )
      or (
        aiqr.source_run_id is not null
        and expected_job_type is not null
        and air.task = expected_job_type
      )
    )
    and not exists (
      select 1
      from public.daily_questions as used_dq
      where used_dq.couple_id = target_couple.id
        and used_dq.question_id = q.id
    )
  order by
    case when aiqr.source_follow_up_id is not null then 0 else 1 end,
    aiqr.created_at,
    aiqr.id
  limit 1
  for update of aiqr;

  if selected_question_id is null then
    return null;
  end if;

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date,
    story_loop_id
  )
  values (
    target_couple.id,
    selected_question_id,
    target_story_loop.couple_date,
    target_story_loop.id
  )
  on conflict on constraint daily_questions_couple_date_unique do nothing;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = target_story_loop.couple_date
  for update;

  if not found
    or target_daily_question.story_loop_id <> target_story_loop.id
    or target_daily_question.question_id <> selected_question_id
  then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  update public.ai_question_recommendations as aiqr
  set
    status = 'used',
    assigned_daily_question_id = target_daily_question.id,
    used_at = now()
  where aiqr.id = selected_recommendation_id
    and aiqr.status = 'pending';

  return target_daily_question;
end;
$$;

revoke execute on function
  private.normalize_ai_question_text(text)
  from public, anon, authenticated;
revoke execute on function
  private.is_safe_ai_direct_follow_up_question(text)
  from public, anon, authenticated;
revoke execute on function
  private.enforce_ai_question_queue_capacity()
  from public, anon, authenticated;
revoke execute on function
  private.get_recent_ai_shared_question_texts(uuid, integer)
  from public, anon, authenticated;
revoke execute on function
  private.assign_pending_ai_question_to_story_loop(
    public.couples,
    public.daily_story_loops
  ) from public, anon, authenticated;

revoke execute on function
  public.decide_ai_user_question_follow_up(uuid, text)
  from public, anon;
grant execute on function
  public.decide_ai_user_question_follow_up(uuid, text)
  to authenticated;

revoke execute on function public.get_my_ai_user_questions()
  from public, anon;
revoke execute on function public.delete_my_ai_user_question(uuid)
  from public, anon;
grant execute on function public.get_my_ai_user_questions()
  to authenticated;
grant execute on function public.delete_my_ai_user_question(uuid)
  to authenticated;
