alter table private.ai_proactive_suggestion_daily_usage
  drop constraint if exists ai_proactive_daily_session_count_check;

alter table private.ai_proactive_suggestion_daily_usage
  add constraint ai_proactive_daily_session_count_check
  check (cardinality(shown_session_ids) <= 100);

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

    if cardinality(daily_usage.shown_session_ids) < 100 then
      update private.ai_proactive_suggestion_daily_usage as usage
      set
        shown_session_ids = array_append(
          usage.shown_session_ids,
          normalized_session_id
        ),
        updated_at = now()
      where usage.user_id = current_user_id
        and usage.context_date = requested_context_date;
    end if;
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
