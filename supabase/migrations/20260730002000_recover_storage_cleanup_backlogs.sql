alter table public.storage_cleanup_requests
  add column attempt_count integer not null default 0,
  add column max_attempts integer not null default 5,
  add column available_at timestamptz not null default now(),
  add column claim_token uuid,
  add column claimed_by text,
  add column claimed_at timestamptz,
  add column completion_outcome text;

alter table public.storage_cleanup_requests
  add constraint storage_cleanup_requests_attempt_count_check
    check (attempt_count between 0 and max_attempts),
  add constraint storage_cleanup_requests_max_attempts_check
    check (max_attempts between 1 and 10),
  add constraint storage_cleanup_requests_claimed_by_check
    check (
      claimed_by is null
      or char_length(claimed_by) between 1 and 120
    ),
  add constraint storage_cleanup_requests_completion_outcome_check
    check (
      completion_outcome is null
      or completion_outcome in ('deleted', 'still_referenced')
    );

create index storage_cleanup_requests_claim_idx
  on public.storage_cleanup_requests (
    status,
    available_at,
    created_at,
    id
  )
  where status in ('pending', 'processing');

create index storage_cleanup_requests_stale_claim_idx
  on public.storage_cleanup_requests (claimed_at, id)
  where status = 'processing';

create index story_loop_cards_preview_path_idx
  on public.story_loop_cards (preview_path);
create index story_loop_cards_scene_data_path_idx
  on public.story_loop_cards (scene_data_path);
create index story_loop_cards_background_image_path_idx
  on public.story_loop_cards (background_image_path)
  where background_image_path is not null;
create index couple_characters_image_path_idx
  on public.couple_characters (image_path);
create index couple_characters_drawing_data_path_idx
  on public.couple_characters (drawing_data_path);
create index couple_recording_slots_artwork_preview_path_idx
  on public.couple_recording_slots (artwork_preview_path)
  where artwork_preview_path is not null;
create index couple_recording_slots_artwork_data_path_idx
  on public.couple_recording_slots (artwork_data_path)
  where artwork_data_path is not null;
create index couple_calendar_events_artwork_preview_path_idx
  on public.couple_calendar_events (artwork_preview_path)
  where artwork_preview_path is not null;
create index couple_calendar_events_artwork_data_path_idx
  on public.couple_calendar_events (artwork_data_path)
  where artwork_data_path is not null;

grant all on table public.storage_cleanup_requests to service_role;

create or replace function public.is_storage_cleanup_object_referenced(
  requested_bucket_id text,
  requested_object_path text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  normalized_bucket_id text := nullif(btrim(requested_bucket_id), '');
  normalized_object_path text := nullif(btrim(requested_object_path), '');
begin
  if normalized_bucket_id is null or normalized_object_path is null then
    return true;
  end if;

  case normalized_bucket_id
    when 'story-cards' then
      return exists (
        select 1
        from public.story_loop_cards as card
        where card.preview_path = normalized_object_path
          or card.scene_data_path = normalized_object_path
          or card.background_image_path = normalized_object_path
      );
    when 'couple-recordings' then
      return exists (
        select 1
        from public.couple_recordings as recording
        where recording.storage_path = normalized_object_path
      );
    when 'couple-characters' then
      return exists (
        select 1
        from public.couple_characters as character
        where character.image_path = normalized_object_path
          or character.drawing_data_path = normalized_object_path
      );
    when 'couple-recording-artworks' then
      return exists (
        select 1
        from public.couple_recording_slots as slot
        where slot.artwork_preview_path = normalized_object_path
          or slot.artwork_data_path = normalized_object_path
      );
    when 'couple-calendar-artworks' then
      return exists (
        select 1
        from public.couple_calendar_events as event
        where event.artwork_preview_path = normalized_object_path
          or event.artwork_data_path = normalized_object_path
      );
    else
      return true;
  end case;
end;
$$;

create or replace function public.reconcile_storage_cleanup_requests(
  requested_limit integer default 100,
  requested_minimum_age_minutes integer default 60
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  inserted_count integer;
begin
  if requested_limit is null
    or requested_limit < 1
    or requested_limit > 500
  then
    perform private.raise_app_error('invalid_storage_reconcile_limit');
  end if;

  if requested_minimum_age_minutes is null
    or requested_minimum_age_minutes < 15
    or requested_minimum_age_minutes > 1440
  then
    perform private.raise_app_error('invalid_storage_reconcile_age');
  end if;

  with candidates as materialized (
    select
      object.bucket_id,
      object.name as object_path,
      case object.bucket_id
        when 'couple-recordings' then 'orphan_recording'
        when 'couple-characters' then 'orphan_character'
        when 'story-cards' then 'orphan_story_card'
        when 'couple-recording-artworks' then 'orphan_recording_artwork'
        when 'couple-calendar-artworks' then 'orphan_calendar_artwork'
      end as cleanup_reason
    from storage.objects as object
    where object.bucket_id in (
        'couple-recordings',
        'couple-characters',
        'story-cards',
        'couple-recording-artworks',
        'couple-calendar-artworks'
      )
      and object.created_at <=
        now() - make_interval(mins => requested_minimum_age_minutes)
      and not public.is_storage_cleanup_object_referenced(
        object.bucket_id,
        object.name
      )
      and not exists (
        select 1
        from public.storage_cleanup_requests as request
        where request.bucket_id = object.bucket_id
          and request.object_path = object.name
          and request.status in ('pending', 'processing', 'failed')
      )
    order by object.created_at, object.bucket_id, object.name
    limit requested_limit
  )
  insert into public.storage_cleanup_requests (
    bucket_id,
    object_path,
    cleanup_reason
  )
  select
    candidates.bucket_id,
    candidates.object_path,
    candidates.cleanup_reason
  from candidates
  on conflict do nothing;

  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create or replace function public.claim_storage_cleanup_requests(
  requested_worker_id text,
  requested_limit integer default 20,
  requested_request_id uuid default null
)
returns table (
  request_id uuid,
  claim_token uuid,
  attempt_count integer,
  max_attempts integer,
  bucket_id text,
  object_path text,
  cleanup_reason text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_worker_id text := nullif(btrim(requested_worker_id), '');
  stale_claimed_before timestamptz := now() - interval '5 minutes';
begin
  if normalized_worker_id is null
    or char_length(normalized_worker_id) > 120
  then
    perform private.raise_app_error('invalid_storage_cleanup_worker_id');
  end if;

  if requested_limit is null
    or requested_limit < 1
    or requested_limit > 100
  then
    perform private.raise_app_error('invalid_storage_cleanup_claim_limit');
  end if;

  update public.storage_cleanup_requests as request
  set
    status = 'failed',
    claim_token = null,
    claimed_by = null,
    claimed_at = null,
    processed_at = now(),
    completion_outcome = null,
    last_error = coalesce(
      request.last_error,
      'storage_cleanup_abandoned_after_final_attempt'
    )
  where request.status = 'processing'
    and (
      request.claim_token is null
      or request.claimed_at is null
      or request.claimed_at < stale_claimed_before
    )
    and request.attempt_count >= request.max_attempts;

  return query
  with candidates as (
    select request.id
    from public.storage_cleanup_requests as request
    where (
        requested_request_id is null
        or request.id = requested_request_id
      )
      and request.attempt_count < request.max_attempts
      and (
        (
          request.status = 'pending'
          and request.available_at <= now()
        )
        or (
          request.status = 'failed'
          and request.attempt_count = 0
        )
        or (
          request.status = 'processing'
          and (
            request.claim_token is null
            or request.claimed_at is null
            or request.claimed_at < stale_claimed_before
          )
        )
      )
    order by request.available_at, request.created_at, request.id
    for update skip locked
    limit requested_limit
  ),
  claimed as (
    update public.storage_cleanup_requests as request
    set
      status = 'processing',
      attempt_count = request.attempt_count + 1,
      claim_token = gen_random_uuid(),
      claimed_by = normalized_worker_id,
      claimed_at = now(),
      processed_at = null,
      completion_outcome = null,
      last_error = null
    from candidates
    where request.id = candidates.id
    returning request.*
  )
  select
    claimed.id,
    claimed.claim_token,
    claimed.attempt_count,
    claimed.max_attempts,
    claimed.bucket_id,
    claimed.object_path,
    claimed.cleanup_reason
  from claimed
  order by claimed.created_at, claimed.id;
end;
$$;

create or replace function public.complete_storage_cleanup_request(
  requested_request_id uuid,
  requested_claim_token uuid,
  requested_succeeded boolean,
  requested_outcome text default null,
  requested_error text default null,
  requested_retry_delay_seconds integer default 60
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_outcome text := nullif(btrim(requested_outcome), '');
  normalized_error text := nullif(btrim(requested_error), '');
  claimed_request public.storage_cleanup_requests%rowtype;
  next_status text;
begin
  if requested_request_id is null or requested_claim_token is null then
    perform private.raise_app_error('invalid_storage_cleanup_claim');
  end if;

  if requested_succeeded is null then
    perform private.raise_app_error('invalid_storage_cleanup_result');
  end if;

  if requested_retry_delay_seconds is null
    or requested_retry_delay_seconds < 0
    or requested_retry_delay_seconds > 3600
  then
    perform private.raise_app_error('invalid_storage_cleanup_retry_delay');
  end if;

  if requested_succeeded then
    if normalized_outcome is null
      or normalized_outcome not in ('deleted', 'still_referenced')
    then
      perform private.raise_app_error('invalid_storage_cleanup_outcome');
    end if;
    if normalized_error is not null then
      perform private.raise_app_error('invalid_storage_cleanup_error');
    end if;
  else
    if normalized_outcome is not null or normalized_error is null then
      perform private.raise_app_error('invalid_storage_cleanup_error');
    end if;
    if char_length(normalized_error) > 2000 then
      perform private.raise_app_error('storage_cleanup_error_too_long');
    end if;
  end if;

  select request.*
  into claimed_request
  from public.storage_cleanup_requests as request
  where request.id = requested_request_id
    and request.status = 'processing'
    and request.claim_token = requested_claim_token
  for update;

  if not found then
    return 'stale';
  end if;

  if requested_succeeded then
    next_status := 'completed';

    update public.storage_cleanup_requests
    set
      status = next_status,
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completion_outcome = normalized_outcome,
      processed_at = now(),
      last_error = null
    where id = claimed_request.id;
  elsif claimed_request.attempt_count >= claimed_request.max_attempts then
    next_status := 'failed';

    update public.storage_cleanup_requests
    set
      status = next_status,
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completion_outcome = null,
      processed_at = now(),
      last_error = normalized_error
    where id = claimed_request.id;
  else
    next_status := 'pending';

    update public.storage_cleanup_requests
    set
      status = next_status,
      available_at =
        now() + make_interval(secs => requested_retry_delay_seconds),
      claim_token = null,
      claimed_by = null,
      claimed_at = null,
      completion_outcome = null,
      processed_at = null,
      last_error = normalized_error
    where id = claimed_request.id;
  end if;

  return next_status;
end;
$$;

revoke execute on function public.is_storage_cleanup_object_referenced(
  text,
  text
) from public, anon, authenticated;
revoke execute on function public.reconcile_storage_cleanup_requests(
  integer,
  integer
) from public, anon, authenticated;
revoke execute on function public.claim_storage_cleanup_requests(
  text,
  integer,
  uuid
) from public, anon, authenticated;
revoke execute on function public.complete_storage_cleanup_request(
  uuid,
  uuid,
  boolean,
  text,
  text,
  integer
) from public, anon, authenticated;

grant execute on function public.is_storage_cleanup_object_referenced(
  text,
  text
) to service_role;
grant execute on function public.reconcile_storage_cleanup_requests(
  integer,
  integer
) to service_role;
grant execute on function public.claim_storage_cleanup_requests(
  text,
  integer,
  uuid
) to service_role;
grant execute on function public.complete_storage_cleanup_request(
  uuid,
  uuid,
  boolean,
  text,
  text,
  integer
) to service_role;
