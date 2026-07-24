create or replace function private.get_ai_user_personalization_context(
  target_couple_id uuid,
  target_user_id uuid,
  maximum_memories_per_subject integer
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
  if maximum_memories_per_subject is not null
    and maximum_memories_per_subject <= 0
  then
    perform private.raise_app_error('invalid_ai_personalization_context');
  end if;

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
        'subject', ranked_memory.memory_subject,
        'kind', ranked_memory.kind,
        'learning_domain', ranked_memory.learning_domain,
        'statement', ranked_memory.statement,
        'confidence', ranked_memory.confidence
      )
      order by ranked_memory.updated_at desc, ranked_memory.id
    ),
    '[]'::jsonb
  )
  into memories_json
  from (
    select
      aim.*,
      case
        when aim.scope = 'couple' then 'couple'
        when aim.subject_user_id = target_user_id then 'me'
        else 'partner'
      end as memory_subject,
      row_number() over (
        partition by case
          when aim.scope = 'couple' then 'couple'
          when aim.subject_user_id = target_user_id then 'me'
          else 'partner'
        end
        order by aim.updated_at desc, aim.id
      ) as subject_position
    from public.ai_memories as aim
    where aim.couple_id = target_couple_id
      and aim.state = 'active'
  ) as ranked_memory
  where maximum_memories_per_subject is null
    or ranked_memory.subject_position <= maximum_memories_per_subject;

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

create or replace function private.get_ai_user_personalization_context(
  target_couple_id uuid,
  target_user_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.get_ai_user_personalization_context(
    target_couple_id,
    target_user_id,
    null
  );
$$;

revoke execute on function
  private.get_ai_user_personalization_context(uuid, uuid, integer)
  from public, anon, authenticated;

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
      requested_user_id,
      16
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

create table private.ai_proactive_suggestion_daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  context_date date not null,
  generation_count smallint not null default 0,
  shown_session_ids text[] not null default '{}'::text[],
  updated_at timestamptz not null default now(),

  primary key (user_id, context_date),
  constraint ai_proactive_daily_generation_count_check
    check (generation_count between 0 and 6),
  constraint ai_proactive_daily_session_count_check
    check (cardinality(shown_session_ids) <= 3)
);

revoke all on table private.ai_proactive_suggestion_daily_usage
  from public, anon, authenticated;

create or replace function public.claim_ai_proactive_suggestion_generation(
  requested_user_id uuid,
  requested_context_date date
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  current_couple_date date;
  claimed_count smallint;
begin
  if requested_user_id is null or requested_context_date is null then
    perform private.raise_app_error('invalid_ai_proactive_generation_claim');
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
  if requested_context_date <> current_couple_date then
    perform private.raise_app_error('invalid_ai_proactive_generation_claim');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_proactive_daily_usage'),
    hashtext(requested_user_id::text || ':' || requested_context_date::text)
  );

  delete from private.ai_proactive_suggestion_daily_usage as usage
  where usage.user_id = requested_user_id
    and usage.context_date < current_couple_date - 30;

  insert into private.ai_proactive_suggestion_daily_usage as usage (
    user_id,
    context_date,
    generation_count
  )
  values (
    requested_user_id,
    requested_context_date,
    1
  )
  on conflict (user_id, context_date) do update
  set
    generation_count = usage.generation_count + 1,
    updated_at = now()
  where usage.generation_count < 6
    and cardinality(usage.shown_session_ids) < 3
  returning generation_count
  into claimed_count;

  return claimed_count is not null;
end;
$$;

create or replace function public.claim_my_ai_proactive_suggestion_impression(
  requested_context_date date,
  requested_session_id text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_session_id text := nullif(btrim(requested_session_id), '');
  active_couple public.couples%rowtype;
  current_couple_date date;
  daily_usage private.ai_proactive_suggestion_daily_usage%rowtype;
begin
  if current_user_id is null
    or requested_context_date is null
    or normalized_session_id is null
    or char_length(normalized_session_id) > 160
  then
    perform private.raise_app_error('invalid_ai_proactive_impression_claim');
  end if;

  select c.*
  into active_couple
  from public.couples as c
  where c.status = 'active'
    and current_user_id in (c.user_a_id, c.user_b_id)
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
  if requested_context_date <> current_couple_date then
    return false;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('ai_proactive_daily_usage'),
    hashtext(current_user_id::text || ':' || requested_context_date::text)
  );

  delete from private.ai_proactive_suggestion_daily_usage as usage
  where usage.user_id = current_user_id
    and usage.context_date < current_couple_date - 30;

  select usage.*
  into daily_usage
  from private.ai_proactive_suggestion_daily_usage as usage
  where usage.user_id = current_user_id
    and usage.context_date = requested_context_date
  for update;

  if found then
    if normalized_session_id = any(daily_usage.shown_session_ids) then
      return true;
    end if;
    if cardinality(daily_usage.shown_session_ids) >= 3 then
      return false;
    end if;

    update private.ai_proactive_suggestion_daily_usage as usage
    set
      shown_session_ids = array_append(
        usage.shown_session_ids,
        normalized_session_id
      ),
      updated_at = now()
    where usage.user_id = current_user_id
      and usage.context_date = requested_context_date;
    return true;
  end if;

  insert into private.ai_proactive_suggestion_daily_usage (
    user_id,
    context_date,
    shown_session_ids
  )
  values (
    current_user_id,
    requested_context_date,
    array[normalized_session_id]
  );
  return true;
end;
$$;

revoke execute on function
  public.claim_ai_proactive_suggestion_generation(uuid, date)
  from public, anon, authenticated;
revoke execute on function
  public.claim_my_ai_proactive_suggestion_impression(date, text)
  from public, anon;

grant execute on function
  public.claim_ai_proactive_suggestion_generation(uuid, date)
  to service_role;
grant execute on function
  public.claim_my_ai_proactive_suggestion_impression(date, text)
  to authenticated;
