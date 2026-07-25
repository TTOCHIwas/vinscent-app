insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'couple-calendar-artworks',
  'couple-calendar-artworks',
  false,
  262144,
  array[
    'image/webp',
    'application/gzip'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.storage_cleanup_requests
  drop constraint if exists storage_cleanup_requests_bucket_id_check,
  drop constraint if exists storage_cleanup_requests_cleanup_reason_check;

alter table public.storage_cleanup_requests
  add constraint storage_cleanup_requests_bucket_id_check
    check (
      bucket_id in (
        'couple-recordings',
        'couple-characters',
        'story-cards',
        'couple-recording-artworks',
        'couple-calendar-artworks'
      )
    ) not valid,
  add constraint storage_cleanup_requests_cleanup_reason_check
    check (
      cleanup_reason in (
        'orphan_recording',
        'archive_recording',
        'archive_character',
        'orphan_character',
        'orphan_story_card',
        'archive_story_card',
        'orphan_recording_artwork',
        'archive_recording_artwork',
        'orphan_calendar_artwork',
        'archive_calendar_artwork'
      )
    ) not valid;

alter table public.storage_cleanup_requests
  validate constraint storage_cleanup_requests_bucket_id_check;

alter table public.storage_cleanup_requests
  validate constraint storage_cleanup_requests_cleanup_reason_check;

create table public.couple_calendar_events (
  id uuid primary key,
  couple_id uuid not null references public.couples(id) on delete cascade,
  title text not null,
  event_date date not null,
  repeat_rule text not null default 'none',
  memo text,
  artwork_preview_path text,
  artwork_data_path text,
  revision integer not null default 1,
  created_by_user_id uuid not null references auth.users(id) on delete restrict,
  updated_by_user_id uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint couple_calendar_events_id_couple_unique
    unique (id, couple_id),
  constraint couple_calendar_events_title_check
    check (char_length(btrim(title)) between 1 and 30),
  constraint couple_calendar_events_repeat_rule_check
    check (repeat_rule in ('none', 'yearly')),
  constraint couple_calendar_events_memo_check
    check (memo is null or char_length(memo) <= 500),
  constraint couple_calendar_events_artwork_pair_check
    check (
      (artwork_preview_path is null and artwork_data_path is null)
      or
      (artwork_preview_path is not null and artwork_data_path is not null)
    ),
  constraint couple_calendar_events_revision_check
    check (revision >= 1)
);

create index couple_calendar_events_couple_date_idx
  on public.couple_calendar_events (couple_id, event_date, created_at, id);

create index couple_calendar_events_yearly_idx
  on public.couple_calendar_events (
    couple_id,
    extract(month from event_date),
    extract(day from event_date)
  )
  where repeat_rule = 'yearly';

create trigger couple_calendar_events_set_updated_at
  before update on public.couple_calendar_events
  for each row
  execute function public.set_updated_at();

create table public.couple_calendar_event_reminders (
  event_id uuid not null,
  couple_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  is_enabled boolean not null default false,
  offset_days integer not null default 0,
  reminder_time time not null default '09:00:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (event_id, user_id),
  constraint couple_calendar_event_reminders_event_fk
    foreign key (event_id, couple_id)
    references public.couple_calendar_events(id, couple_id)
    on delete cascade,
  constraint couple_calendar_event_reminders_offset_check
    check (offset_days in (0, 1, 3, 7))
);

create index couple_calendar_event_reminders_due_idx
  on public.couple_calendar_event_reminders (
    is_enabled,
    couple_id,
    reminder_time
  )
  where is_enabled;

create trigger couple_calendar_event_reminders_set_updated_at
  before update on public.couple_calendar_event_reminders
  for each row
  execute function public.set_updated_at();

alter table public.couple_calendar_events enable row level security;
alter table public.couple_calendar_event_reminders enable row level security;

create policy "couple_calendar_events_select_member"
  on public.couple_calendar_events
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "couple_calendar_event_reminders_select_own"
  on public.couple_calendar_event_reminders
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    and private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create or replace function private.is_current_user_writable_calendar_artwork(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-calendar-artworks'
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and object_name ~ (
          '^'
          || c.id::text
          || '/events/[0-9a-f-]{36}/artworks/[0-9a-f-]{36}/'
          || '(preview[.]webp|drawing[.]json[.]gz)$'
        )
    );
$$;

create or replace function private.is_current_user_readable_calendar_artwork(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select object_bucket_id = 'couple-calendar-artworks'
    and exists (
      select 1
      from public.couple_calendar_events as cce
      where private.is_readable_couple_member(
          cce.couple_id,
          (select auth.uid())
        )
        and object_name in (
          cce.artwork_preview_path,
          cce.artwork_data_path
        )
    );
$$;

create policy "couple_calendar_artworks_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.is_current_user_writable_calendar_artwork(bucket_id, name)
  );

create policy "couple_calendar_artworks_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    private.is_current_user_readable_calendar_artwork(bucket_id, name)
  );

create or replace function private.calendar_event_occurrence_date(
  base_date date,
  target_year integer
)
returns date
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  base_month integer;
  base_day integer;
begin
  if base_date is null or target_year is null then
    return null;
  end if;

  base_month := extract(month from base_date)::integer;
  base_day := extract(day from base_date)::integer;

  if base_month = 2
    and base_day = 29
    and not (
      target_year % 400 = 0
      or (target_year % 4 = 0 and target_year % 100 <> 0)
    )
  then
    return make_date(target_year, 2, 28);
  end if;

  return make_date(target_year, base_month, base_day);
end;
$$;

create or replace function private.enqueue_calendar_event_artwork_cleanup()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.artwork_preview_path is not null then
    perform private.enqueue_storage_cleanup_request(
      'couple-calendar-artworks',
      old.artwork_preview_path,
      'orphan_calendar_artwork',
      old.couple_id
    );
  end if;

  if old.artwork_data_path is not null then
    perform private.enqueue_storage_cleanup_request(
      'couple-calendar-artworks',
      old.artwork_data_path,
      'orphan_calendar_artwork',
      old.couple_id
    );
  end if;

  return old;
end;
$$;

create trigger couple_calendar_events_cleanup_artwork_before_delete
  before delete on public.couple_calendar_events
  for each row
  execute function private.enqueue_calendar_event_artwork_cleanup();

create function public.get_couple_calendar_event_occurrences(
  target_start_date date,
  target_end_date date
)
returns table (
  event_id uuid,
  couple_id uuid,
  title text,
  event_date date,
  occurrence_date date,
  repeat_rule text,
  memo text,
  artwork_preview_path text,
  artwork_data_path text,
  revision integer,
  created_by_user_id uuid,
  updated_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  own_reminder_enabled boolean,
  own_reminder_offset_days integer,
  own_reminder_time time
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  readable_couple public.couples%rowtype;
  normalized_start_date date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if target_start_date is null
    or target_end_date is null
    or target_end_date < target_start_date
    or target_end_date - target_start_date > 62
  then
    perform private.raise_app_error('invalid_calendar_event_range');
  end if;

  readable_couple := private.get_readable_couple_for_current_user();

  if readable_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_end_date < readable_couple.relationship_start_date then
    return;
  end if;

  normalized_start_date := greatest(
    target_start_date,
    readable_couple.relationship_start_date
  );

  return query
    with target_days as (
      select generated_day::date as occurrence_date
      from generate_series(
        normalized_start_date::timestamp,
        target_end_date::timestamp,
        interval '1 day'
      ) as generated_day
    )
    select
      cce.id,
      cce.couple_id,
      cce.title,
      cce.event_date,
      target_days.occurrence_date,
      cce.repeat_rule,
      cce.memo,
      cce.artwork_preview_path,
      cce.artwork_data_path,
      cce.revision,
      cce.created_by_user_id,
      cce.updated_by_user_id,
      cce.created_at,
      cce.updated_at,
      coalesce(ccer.is_enabled, false),
      coalesce(ccer.offset_days, 0),
      coalesce(ccer.reminder_time, '09:00:00'::time)
    from target_days
    join public.couple_calendar_events as cce
      on cce.couple_id = readable_couple.id
      and (
        (
          cce.repeat_rule = 'none'
          and cce.event_date = target_days.occurrence_date
        )
        or
        (
          cce.repeat_rule = 'yearly'
          and target_days.occurrence_date >= cce.event_date
          and target_days.occurrence_date
            = private.calendar_event_occurrence_date(
              cce.event_date,
              extract(year from target_days.occurrence_date)::integer
            )
        )
      )
    left join public.couple_calendar_event_reminders as ccer
      on ccer.event_id = cce.id
      and ccer.user_id = current_user_id
    order by
      target_days.occurrence_date,
      (cce.artwork_preview_path is null),
      cce.created_at,
      cce.id;
end;
$$;

create function public.get_couple_calendar_event(
  requested_event_id uuid
)
returns table (
  event_id uuid,
  couple_id uuid,
  title text,
  event_date date,
  occurrence_date date,
  repeat_rule text,
  memo text,
  artwork_preview_path text,
  artwork_data_path text,
  revision integer,
  created_by_user_id uuid,
  updated_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  own_reminder_enabled boolean,
  own_reminder_offset_days integer,
  own_reminder_time time
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  readable_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_event_id is null then
    perform private.raise_app_error('invalid_calendar_event');
  end if;

  readable_couple := private.get_readable_couple_for_current_user();

  return query
    select
      cce.id,
      cce.couple_id,
      cce.title,
      cce.event_date,
      cce.event_date,
      cce.repeat_rule,
      cce.memo,
      cce.artwork_preview_path,
      cce.artwork_data_path,
      cce.revision,
      cce.created_by_user_id,
      cce.updated_by_user_id,
      cce.created_at,
      cce.updated_at,
      coalesce(ccer.is_enabled, false),
      coalesce(ccer.offset_days, 0),
      coalesce(ccer.reminder_time, '09:00:00'::time)
    from public.couple_calendar_events as cce
    left join public.couple_calendar_event_reminders as ccer
      on ccer.event_id = cce.id
      and ccer.user_id = current_user_id
    where cce.id = requested_event_id
      and cce.couple_id = readable_couple.id;
end;
$$;

create function public.save_couple_calendar_event(
  requested_event_id uuid,
  requested_title text,
  requested_event_date date,
  requested_repeat_rule text,
  requested_memo text,
  requested_artwork_revision uuid,
  requested_remove_artwork boolean,
  requested_reminder_enabled boolean,
  requested_reminder_offset_days integer,
  requested_reminder_time time,
  expected_event_revision integer
)
returns table (
  event_id uuid,
  couple_id uuid,
  title text,
  event_date date,
  occurrence_date date,
  repeat_rule text,
  memo text,
  artwork_preview_path text,
  artwork_data_path text,
  revision integer,
  created_by_user_id uuid,
  updated_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  own_reminder_enabled boolean,
  own_reminder_offset_days integer,
  own_reminder_time time
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  existing_event public.couple_calendar_events%rowtype;
  saved_event public.couple_calendar_events%rowtype;
  normalized_title text := btrim(requested_title);
  normalized_repeat_rule text := btrim(requested_repeat_rule);
  normalized_memo text := nullif(btrim(requested_memo), '');
  next_preview_path text;
  next_data_path text;
  previous_preview_path text;
  previous_data_path text;
  current_couple_date date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_event_id is null then
    perform private.raise_app_error('invalid_calendar_event');
  end if;

  if normalized_title is null
    or char_length(normalized_title) < 1
    or char_length(normalized_title) > 30
  then
    perform private.raise_app_error('invalid_calendar_event_title');
  end if;

  if requested_event_date is null then
    perform private.raise_app_error('invalid_calendar_event_date');
  end if;

  if normalized_repeat_rule not in ('none', 'yearly') then
    perform private.raise_app_error('invalid_calendar_event_repeat_rule');
  end if;

  if normalized_memo is not null and char_length(normalized_memo) > 500 then
    perform private.raise_app_error('invalid_calendar_event_memo');
  end if;

  if requested_remove_artwork is null
    or requested_reminder_enabled is null
    or (
      requested_artwork_revision is not null
      and requested_remove_artwork
    )
  then
    perform private.raise_app_error('invalid_calendar_event_artwork');
  end if;

  if requested_reminder_offset_days not in (0, 1, 3, 7)
    or requested_reminder_time is null
  then
    perform private.raise_app_error('invalid_calendar_event_reminder');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  current_couple_date := private.current_date_in_timezone(
    active_couple.timezone
  );

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if requested_event_date < active_couple.relationship_start_date then
    perform private.raise_app_error('calendar_event_before_relationship_start');
  end if;

  if requested_reminder_enabled
    and normalized_repeat_rule = 'none'
    and requested_event_date < current_couple_date
  then
    perform private.raise_app_error('calendar_event_reminder_in_past');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_calendar_event'),
    hashtext(requested_event_id::text)
  );

  select *
  into existing_event
  from public.couple_calendar_events as cce
  where cce.id = requested_event_id
  for update;

  if found then
    if existing_event.couple_id <> active_couple.id then
      perform private.raise_app_error('calendar_event_not_found');
    end if;

    if expected_event_revision is null
      or existing_event.revision <> expected_event_revision
    then
      perform private.raise_app_error('calendar_event_conflict');
    end if;

    previous_preview_path := existing_event.artwork_preview_path;
    previous_data_path := existing_event.artwork_data_path;
    next_preview_path := existing_event.artwork_preview_path;
    next_data_path := existing_event.artwork_data_path;
  else
    if expected_event_revision is not null then
      perform private.raise_app_error('calendar_event_conflict');
    end if;
  end if;

  if requested_remove_artwork then
    next_preview_path := null;
    next_data_path := null;
  elsif requested_artwork_revision is not null then
    next_preview_path := active_couple.id::text
      || '/events/' || requested_event_id::text
      || '/artworks/' || requested_artwork_revision::text
      || '/preview.webp';
    next_data_path := active_couple.id::text
      || '/events/' || requested_event_id::text
      || '/artworks/' || requested_artwork_revision::text
      || '/drawing.json.gz';

    if not exists (
      select 1
      from storage.objects as so
      where so.bucket_id = 'couple-calendar-artworks'
        and so.name = next_preview_path
    ) or not exists (
      select 1
      from storage.objects as so
      where so.bucket_id = 'couple-calendar-artworks'
        and so.name = next_data_path
    ) then
      perform private.raise_app_error('calendar_event_artwork_missing');
    end if;
  end if;

  if existing_event.id is null then
    insert into public.couple_calendar_events (
      id,
      couple_id,
      title,
      event_date,
      repeat_rule,
      memo,
      artwork_preview_path,
      artwork_data_path,
      created_by_user_id,
      updated_by_user_id
    )
    values (
      requested_event_id,
      active_couple.id,
      normalized_title,
      requested_event_date,
      normalized_repeat_rule,
      normalized_memo,
      next_preview_path,
      next_data_path,
      current_user_id,
      current_user_id
    )
    returning *
    into saved_event;
  else
    update public.couple_calendar_events as cce
    set
      title = normalized_title,
      event_date = requested_event_date,
      repeat_rule = normalized_repeat_rule,
      memo = normalized_memo,
      artwork_preview_path = next_preview_path,
      artwork_data_path = next_data_path,
      revision = cce.revision + 1,
      updated_by_user_id = current_user_id
    where cce.id = requested_event_id
    returning *
    into saved_event;
  end if;

  insert into public.couple_calendar_event_reminders (
    event_id,
    couple_id,
    user_id,
    is_enabled,
    offset_days,
    reminder_time
  )
  values (
    saved_event.id,
    saved_event.couple_id,
    current_user_id,
    requested_reminder_enabled,
    requested_reminder_offset_days,
    requested_reminder_time
  )
  on conflict on constraint couple_calendar_event_reminders_pkey do update
  set
    is_enabled = excluded.is_enabled,
    offset_days = excluded.offset_days,
    reminder_time = excluded.reminder_time;

  if previous_preview_path is not null
    and previous_preview_path is distinct from next_preview_path
  then
    perform private.enqueue_storage_cleanup_request(
      'couple-calendar-artworks',
      previous_preview_path,
      'orphan_calendar_artwork',
      active_couple.id
    );
  end if;

  if previous_data_path is not null
    and previous_data_path is distinct from next_data_path
  then
    perform private.enqueue_storage_cleanup_request(
      'couple-calendar-artworks',
      previous_data_path,
      'orphan_calendar_artwork',
      active_couple.id
    );
  end if;

  return query
    select
      saved_event.id,
      saved_event.couple_id,
      saved_event.title,
      saved_event.event_date,
      saved_event.event_date,
      saved_event.repeat_rule,
      saved_event.memo,
      saved_event.artwork_preview_path,
      saved_event.artwork_data_path,
      saved_event.revision,
      saved_event.created_by_user_id,
      saved_event.updated_by_user_id,
      saved_event.created_at,
      saved_event.updated_at,
      requested_reminder_enabled,
      requested_reminder_offset_days,
      requested_reminder_time;
end;
$$;

create function public.delete_couple_calendar_event(
  requested_event_id uuid,
  expected_event_revision integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  target_event public.couple_calendar_events%rowtype;
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_event_id is null or expected_event_revision is null then
    perform private.raise_app_error('invalid_calendar_event');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  select *
  into target_event
  from public.couple_calendar_events as cce
  where cce.id = requested_event_id
    and cce.couple_id = active_couple.id
  for update;

  if not found then
    perform private.raise_app_error('calendar_event_not_found');
  end if;

  if target_event.revision <> expected_event_revision then
    perform private.raise_app_error('calendar_event_conflict');
  end if;

  delete from public.couple_calendar_events
  where id = target_event.id;
end;
$$;

create function public.discard_uploaded_couple_calendar_event_artwork(
  requested_event_id uuid,
  requested_artwork_revision uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  preview_path text;
  data_path text;
begin
  if auth.uid() is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_event_id is null or requested_artwork_revision is null then
    perform private.raise_app_error('invalid_calendar_event_artwork');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  preview_path := active_couple.id::text
    || '/events/' || requested_event_id::text
    || '/artworks/' || requested_artwork_revision::text
    || '/preview.webp';
  data_path := active_couple.id::text
    || '/events/' || requested_event_id::text
    || '/artworks/' || requested_artwork_revision::text
    || '/drawing.json.gz';

  if exists (
    select 1
    from public.couple_calendar_events as cce
    where cce.couple_id = active_couple.id
      and (
        cce.artwork_preview_path = preview_path
        or cce.artwork_data_path = data_path
      )
  ) then
    return;
  end if;

  perform private.enqueue_storage_cleanup_request(
    'couple-calendar-artworks',
    preview_path,
    'orphan_calendar_artwork',
    active_couple.id
  );
  perform private.enqueue_storage_cleanup_request(
    'couple-calendar-artworks',
    data_path,
    'orphan_calendar_artwork',
    active_couple.id
  );
end;
$$;

create function public.get_due_couple_calendar_event_reminders(
  requested_run_at timestamptz,
  requested_lookback_minutes integer
)
returns table (
  source_id uuid,
  event_id uuid,
  couple_id uuid,
  receiver_user_id uuid,
  title text,
  occurrence_date date,
  offset_days integer,
  scheduled_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if requested_run_at is null
    or requested_lookback_minutes is null
    or requested_lookback_minutes < 1
    or requested_lookback_minutes > 60
  then
    perform private.raise_app_error('invalid_calendar_reminder_window');
  end if;

  return query
    with reminder_candidates as (
      select
        cce.id as event_id,
        cce.couple_id,
        ccer.user_id as receiver_user_id,
        cce.title,
        ccer.offset_days,
        ccer.reminder_time,
        c.timezone,
        cce.repeat_rule,
        cce.event_date,
        candidate_year.target_year
      from public.couple_calendar_event_reminders as ccer
      join public.couple_calendar_events as cce
        on cce.id = ccer.event_id
        and cce.couple_id = ccer.couple_id
      join public.couples as c
        on c.id = cce.couple_id
        and c.status = 'active'
      cross join lateral generate_series(
        extract(
          year from (
            (
              requested_run_at
              - make_interval(mins => requested_lookback_minutes)
            ) at time zone c.timezone
          )::date + ccer.offset_days
        )::integer,
        extract(
          year from (
            requested_run_at at time zone c.timezone
          )::date + ccer.offset_days
        )::integer
      ) as candidate_year(target_year)
      where ccer.is_enabled
    ),
    resolved_occurrences as (
      select
        reminder_candidates.*,
        case
          when repeat_rule = 'none' then event_date
          else private.calendar_event_occurrence_date(
            event_date,
            target_year
          )
        end as occurrence_date
      from reminder_candidates
    ),
    due_reminders as (
      select
        resolved_occurrences.*,
        (
          (
            resolved_occurrences.occurrence_date
              - resolved_occurrences.offset_days
          )::date + resolved_occurrences.reminder_time
        ) at time zone resolved_occurrences.timezone as scheduled_at
      from resolved_occurrences
      where resolved_occurrences.occurrence_date
        >= resolved_occurrences.event_date
    )
    select
      md5(
        due_reminders.event_id::text
        || ':' || due_reminders.receiver_user_id::text
        || ':' || due_reminders.occurrence_date::text
      )::uuid,
      due_reminders.event_id,
      due_reminders.couple_id,
      due_reminders.receiver_user_id,
      due_reminders.title,
      due_reminders.occurrence_date,
      due_reminders.offset_days,
      due_reminders.scheduled_at
    from due_reminders
    where due_reminders.scheduled_at
        >= requested_run_at
          - make_interval(mins => requested_lookback_minutes)
      and due_reminders.scheduled_at < requested_run_at
    order by due_reminders.scheduled_at, due_reminders.event_id;
end;
$$;

alter table public.push_notification_dispatches
  drop constraint if exists push_notification_dispatches_notification_type_check;

alter table public.push_notification_dispatches
  add constraint push_notification_dispatches_notification_type_check
  check (
    notification_type in (
      'partner_answer_completed',
      'daily_question_delivery',
      'unanswered_reminder',
      'couple_disconnect',
      'recording_activity',
      'partner_story_card_uploaded',
      'question_generated',
      'couple_activity',
      'ai_update',
      'calendar_event_reminder'
    )
  );

alter table public.push_notification_deliveries
  drop constraint if exists push_notification_deliveries_notification_type_check;

alter table public.push_notification_deliveries
  add constraint push_notification_deliveries_notification_type_check
  check (
    notification_type in (
      'partner_answer_completed',
      'daily_question_delivery',
      'unanswered_reminder',
      'couple_disconnect',
      'recording_activity',
      'partner_story_card_uploaded',
      'question_generated',
      'couple_activity',
      'ai_update',
      'calendar_event_reminder'
    )
  );

create or replace function public.claim_push_notification_dispatch(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid
)
returns table (
  claim_result text,
  notification_type text,
  source_id uuid,
  receiver_user_id uuid,
  claim_token uuid,
  dispatch_status text,
  claimed_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_notification_type text := btrim(requested_notification_type);
  stale_claimed_before timestamptz := now() - interval '5 minutes';
  claimed_dispatch public.push_notification_dispatches%rowtype;
begin
  if normalized_notification_type not in (
    'partner_answer_completed',
    'daily_question_delivery',
    'unanswered_reminder',
    'couple_disconnect',
    'recording_activity',
    'partner_story_card_uploaded',
    'question_generated',
    'couple_activity',
    'ai_update',
    'calendar_event_reminder'
  ) then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
  end if;

  if requested_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  insert into public.push_notification_dispatches (
    notification_type,
    source_id,
    receiver_user_id,
    status,
    claimed_at
  )
  values (
    normalized_notification_type,
    requested_source_id,
    requested_receiver_user_id,
    'processing',
    now()
  )
  on conflict do nothing
  returning * into claimed_dispatch;

  if found then
    return query
      select
        'claimed'::text,
        claimed_dispatch.notification_type,
        claimed_dispatch.source_id,
        claimed_dispatch.receiver_user_id,
        claimed_dispatch.claim_token,
        claimed_dispatch.status,
        claimed_dispatch.claimed_at;
    return;
  end if;

  update public.push_notification_dispatches as pnd
  set
    status = 'processing',
    claim_token = gen_random_uuid(),
    claimed_at = now(),
    completed_at = null,
    error_message = null
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id
    and pnd.status = 'processing'
    and pnd.claimed_at < stale_claimed_before
  returning * into claimed_dispatch;

  if found then
    return query
      select
        'claimed'::text,
        claimed_dispatch.notification_type,
        claimed_dispatch.source_id,
        claimed_dispatch.receiver_user_id,
        claimed_dispatch.claim_token,
        claimed_dispatch.status,
        claimed_dispatch.claimed_at;
    return;
  end if;

  select *
  into claimed_dispatch
  from public.push_notification_dispatches as pnd
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id;

  return query
    select
      'duplicate'::text,
      claimed_dispatch.notification_type,
      claimed_dispatch.source_id,
      claimed_dispatch.receiver_user_id,
      claimed_dispatch.claim_token,
      claimed_dispatch.status,
      claimed_dispatch.claimed_at;
end;
$$;

create or replace function public.complete_push_notification_delivery(
  requested_notification_type text,
  requested_source_id uuid,
  requested_receiver_user_id uuid,
  requested_claim_token uuid,
  requested_target_token_count integer,
  requested_success_count integer,
  requested_failure_count integer,
  requested_status text,
  requested_error_message text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_notification_type text := btrim(requested_notification_type);
  normalized_status text := btrim(requested_status);
  normalized_error_message text := nullif(btrim(requested_error_message), '');
  current_dispatch public.push_notification_dispatches%rowtype;
begin
  if normalized_notification_type not in (
    'partner_answer_completed',
    'daily_question_delivery',
    'unanswered_reminder',
    'couple_disconnect',
    'recording_activity',
    'partner_story_card_uploaded',
    'question_generated',
    'couple_activity',
    'ai_update',
    'calendar_event_reminder'
  ) then
    raise exception 'invalid_notification_type';
  end if;

  if requested_source_id is null then
    raise exception 'invalid_notification_source';
  end if;

  if requested_receiver_user_id is null then
    raise exception 'invalid_notification_receiver';
  end if;

  if requested_claim_token is null then
    raise exception 'invalid_dispatch_claim_token';
  end if;

  if normalized_status not in (
    'sent',
    'partial_failure',
    'failed',
    'skipped'
  ) then
    raise exception 'invalid_dispatch_status';
  end if;

  if requested_target_token_count < 0
    or requested_success_count < 0
    or requested_failure_count < 0
    or requested_target_token_count
      <> requested_success_count + requested_failure_count
  then
    raise exception 'invalid_delivery_counts';
  end if;

  select *
  into current_dispatch
  from public.push_notification_dispatches as pnd
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id
  for update;

  if not found then
    raise exception 'dispatch_missing';
  end if;

  if current_dispatch.claim_token <> requested_claim_token then
    raise exception 'dispatch_claim_lost';
  end if;

  if current_dispatch.status <> 'processing' then
    if current_dispatch.status = normalized_status
      and exists (
        select 1
        from public.push_notification_deliveries as pnd
        where pnd.notification_type = normalized_notification_type
          and pnd.source_id = requested_source_id
          and pnd.receiver_user_id = requested_receiver_user_id
          and pnd.target_token_count = requested_target_token_count
          and pnd.success_count = requested_success_count
          and pnd.failure_count = requested_failure_count
          and pnd.status = normalized_status
          and pnd.error_message is not distinct from normalized_error_message
      )
    then
      return 'duplicate';
    end if;

    raise exception 'dispatch_completion_conflict';
  end if;

  insert into public.push_notification_deliveries (
    notification_type,
    source_id,
    receiver_user_id,
    target_token_count,
    success_count,
    failure_count,
    status,
    error_message
  )
  values (
    normalized_notification_type,
    requested_source_id,
    requested_receiver_user_id,
    requested_target_token_count,
    requested_success_count,
    requested_failure_count,
    normalized_status,
    normalized_error_message
  );

  update public.push_notification_dispatches as pnd
  set
    status = normalized_status,
    completed_at = now(),
    error_message = normalized_error_message
  where pnd.notification_type = normalized_notification_type
    and pnd.source_id = requested_source_id
    and pnd.receiver_user_id = requested_receiver_user_id
    and pnd.claim_token = requested_claim_token
    and pnd.status = 'processing';

  return 'completed';
end;
$$;

revoke execute on function private.is_current_user_writable_calendar_artwork(
  text,
  text
) from public, anon, authenticated;
revoke execute on function private.is_current_user_readable_calendar_artwork(
  text,
  text
) from public, anon, authenticated;
revoke execute on function private.calendar_event_occurrence_date(date, integer)
  from public, anon, authenticated;
revoke execute on function private.enqueue_calendar_event_artwork_cleanup()
  from public, anon, authenticated;
revoke execute on function public.get_couple_calendar_event_occurrences(
  date,
  date
) from public, anon;
revoke execute on function public.get_couple_calendar_event(uuid)
  from public, anon;
revoke execute on function public.save_couple_calendar_event(
  uuid,
  text,
  date,
  text,
  text,
  uuid,
  boolean,
  boolean,
  integer,
  time,
  integer
) from public, anon;
revoke execute on function public.delete_couple_calendar_event(uuid, integer)
  from public, anon;
revoke execute on function public.discard_uploaded_couple_calendar_event_artwork(
  uuid,
  uuid
) from public, anon;
revoke execute on function public.get_due_couple_calendar_event_reminders(
  timestamptz,
  integer
) from public, anon, authenticated;
revoke execute on function public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid
) from public, anon, authenticated;
revoke execute on function public.complete_push_notification_delivery(
  text,
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  integer,
  text,
  text
) from public, anon, authenticated;

grant execute on function private.is_current_user_writable_calendar_artwork(
  text,
  text
) to authenticated;
grant execute on function private.is_current_user_readable_calendar_artwork(
  text,
  text
) to authenticated;
grant execute on function public.get_couple_calendar_event_occurrences(
  date,
  date
) to authenticated;
grant execute on function public.get_couple_calendar_event(uuid)
  to authenticated;
grant execute on function public.save_couple_calendar_event(
  uuid,
  text,
  date,
  text,
  text,
  uuid,
  boolean,
  boolean,
  integer,
  time,
  integer
) to authenticated;
grant execute on function public.delete_couple_calendar_event(uuid, integer)
  to authenticated;
grant execute on function public.discard_uploaded_couple_calendar_event_artwork(
  uuid,
  uuid
) to authenticated;
grant execute on function public.get_due_couple_calendar_event_reminders(
  timestamptz,
  integer
) to service_role;
grant execute on function public.claim_push_notification_dispatch(
  text,
  uuid,
  uuid
) to service_role;
grant execute on function public.complete_push_notification_delivery(
  text,
  uuid,
  uuid,
  uuid,
  integer,
  integer,
  integer,
  text,
  text
) to service_role;

do $$
begin
  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_calendar_events'
  ) then
    alter publication supabase_realtime
      add table public.couple_calendar_events;
  end if;
end;
$$;
