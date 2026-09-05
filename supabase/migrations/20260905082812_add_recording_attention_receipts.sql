create table public.couple_current_recording_receipts (
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  seen_recording_id uuid not null references public.couple_recordings(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (couple_id, user_id)
);

create index couple_current_recording_receipts_user_id_idx
  on public.couple_current_recording_receipts(user_id);

alter table public.couple_current_recording_receipts enable row level security;

create policy "couple_current_recording_receipts_select_own"
  on public.couple_current_recording_receipts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create table public.couple_recording_slot_receipts (
  couple_id uuid not null references public.couples(id) on delete cascade,
  slot_id uuid not null references public.couple_recording_slots(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  seen_recording_id uuid not null references public.couple_recordings(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (slot_id, user_id)
);

create index couple_recording_slot_receipts_couple_user_idx
  on public.couple_recording_slot_receipts(couple_id, user_id);

alter table public.couple_recording_slot_receipts enable row level security;

create policy "couple_recording_slot_receipts_select_own"
  on public.couple_recording_slot_receipts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

insert into public.couple_current_recording_receipts (
  couple_id,
  user_id,
  seen_recording_id,
  seen_at
)
select
  couple.id,
  member.user_id,
  current_recording.recording_id,
  now()
from public.couples as couple
join public.couple_current_recordings as current_recording
  on current_recording.couple_id = couple.id
cross join lateral (
  values (couple.user_a_id), (couple.user_b_id)
) as member(user_id)
where member.user_id is not null;

insert into public.couple_recording_slot_receipts (
  couple_id,
  slot_id,
  user_id,
  seen_recording_id,
  seen_at
)
select
  couple.id,
  slot.id,
  member.user_id,
  slot.recording_id,
  now()
from public.couples as couple
join public.couple_recording_slots as slot
  on slot.couple_id = couple.id
cross join lateral (
  values (couple.user_a_id), (couple.user_b_id)
) as member(user_id)
where member.user_id is not null;

create function public.get_couple_recording_attention_state()
returns table (
  current_recording_id uuid,
  current_is_unseen boolean,
  unseen_slot_ids uuid[]
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

  readable_couple := private.get_readable_couple_for_current_user();

  return query
    select
      ccr.recording_id,
      coalesce(
        ccr.recording_id is not null
          and current_recording.sender_user_id <> current_user_id
          and not exists (
            select 1
            from public.couple_current_recording_receipts as receipt
            where receipt.couple_id = readable_couple.id
              and receipt.user_id = current_user_id
              and receipt.seen_recording_id = ccr.recording_id
          ),
        false
      ),
      coalesce(
        array(
          select slot.id
          from public.couple_recording_slots as slot
          join public.couple_recordings as slot_recording
            on slot_recording.id = slot.recording_id
          where slot.couple_id = readable_couple.id
            and coalesce(
              slot.updated_by_user_id,
              slot.created_by_user_id,
              slot_recording.sender_user_id
            ) <> current_user_id
            and not exists (
              select 1
              from public.couple_recording_slot_receipts as receipt
              where receipt.slot_id = slot.id
                and receipt.user_id = current_user_id
                and receipt.seen_recording_id = slot.recording_id
            )
          order by slot.slot_index
        ),
        '{}'::uuid[]
      )
    from (values (1)) as seed(dummy)
    left join public.couple_current_recordings as ccr
      on ccr.couple_id = readable_couple.id
    left join public.couple_recordings as current_recording
      on current_recording.id = ccr.recording_id;
end;
$$;

create function public.acknowledge_current_couple_recording(
  requested_recording_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  readable_couple public.couples%rowtype;
  actual_recording_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;
  if requested_recording_id is null then
    perform private.raise_app_error('invalid_recording_id');
  end if;

  readable_couple := private.get_readable_couple_for_current_user();

  select recording_id
  into actual_recording_id
  from public.couple_current_recordings
  where couple_id = readable_couple.id;

  if actual_recording_id is distinct from requested_recording_id then
    return false;
  end if;

  insert into public.couple_current_recording_receipts (
    couple_id,
    user_id,
    seen_recording_id,
    seen_at
  )
  values (
    readable_couple.id,
    current_user_id,
    requested_recording_id,
    now()
  )
  on conflict (couple_id, user_id)
  do update
  set
    seen_recording_id = excluded.seen_recording_id,
    seen_at = excluded.seen_at;

  return true;
end;
$$;

create function public.acknowledge_couple_recording_slot(
  requested_slot_id uuid,
  requested_recording_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  readable_couple public.couples%rowtype;
  actual_recording_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;
  if requested_slot_id is null or requested_recording_id is null then
    perform private.raise_app_error('invalid_recording_slot');
  end if;

  readable_couple := private.get_readable_couple_for_current_user();

  select recording_id
  into actual_recording_id
  from public.couple_recording_slots
  where id = requested_slot_id
    and couple_id = readable_couple.id;

  if actual_recording_id is distinct from requested_recording_id then
    return false;
  end if;

  insert into public.couple_recording_slot_receipts (
    couple_id,
    slot_id,
    user_id,
    seen_recording_id,
    seen_at
  )
  values (
    readable_couple.id,
    requested_slot_id,
    current_user_id,
    requested_recording_id,
    now()
  )
  on conflict (slot_id, user_id)
  do update
  set
    couple_id = excluded.couple_id,
    seen_recording_id = excluded.seen_recording_id,
    seen_at = excluded.seen_at;

  return true;
end;
$$;

revoke all on table public.couple_current_recording_receipts
  from public, anon, authenticated;
revoke all on table public.couple_recording_slot_receipts
  from public, anon, authenticated;

grant select on table public.couple_current_recording_receipts
  to authenticated;
grant select on table public.couple_recording_slot_receipts
  to authenticated;

revoke execute on function public.get_couple_recording_attention_state()
  from public, anon;
revoke execute on function public.acknowledge_current_couple_recording(uuid)
  from public, anon;
revoke execute on function public.acknowledge_couple_recording_slot(uuid, uuid)
  from public, anon;

grant execute on function public.get_couple_recording_attention_state()
  to authenticated;
grant execute on function public.acknowledge_current_couple_recording(uuid)
  to authenticated;
grant execute on function public.acknowledge_couple_recording_slot(uuid, uuid)
  to authenticated;

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
      and tablename = 'couple_current_recording_receipts'
  ) then
    alter publication supabase_realtime
      add table public.couple_current_recording_receipts;
  end if;

  if exists (
    select 1
    from pg_publication
    where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'couple_recording_slot_receipts'
  ) then
    alter publication supabase_realtime
      add table public.couple_recording_slot_receipts;
  end if;
end;
$$;
