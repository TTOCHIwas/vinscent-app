create table public.ai_memory_attention_receipts (
  memory_id uuid not null references public.ai_memories(id) on delete cascade,
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  seen_memory_updated_at timestamptz not null,
  seen_at timestamptz not null default now(),
  primary key (memory_id, user_id)
);

create index ai_memory_attention_receipts_couple_user_idx
  on public.ai_memory_attention_receipts(couple_id, user_id);

alter table public.ai_memory_attention_receipts enable row level security;

create policy "ai_memory_attention_receipts_select_own"
  on public.ai_memory_attention_receipts
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create function public.get_ai_memory_attention_state()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  unseen_memory_count integer := 0;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    return jsonb_build_object('unseen_memory_count', 0);
  end if;

  select count(*)::integer
  into unseen_memory_count
  from public.list_ai_memories() as visible_memory
  join public.ai_memories as memory
    on memory.id = visible_memory.memory_id
  where visible_memory.memory_state = 'pending'
    and (
      (
        visible_memory.memory_scope = 'personal'
        and visible_memory.subject_user_id = current_user_id
      )
      or visible_memory.memory_scope = 'couple'
    )
    and not exists (
      select 1
      from public.ai_memory_confirmations as confirmation
      where confirmation.memory_id = visible_memory.memory_id
        and confirmation.user_id = current_user_id
    )
    and not exists (
      select 1
      from public.ai_memory_attention_receipts as receipt
      where receipt.memory_id = visible_memory.memory_id
        and receipt.user_id = current_user_id
        and receipt.seen_memory_updated_at = memory.updated_at
    );

  return jsonb_build_object(
    'unseen_memory_count', unseen_memory_count
  );
end;
$$;

create function public.acknowledge_ai_memories(
  requested_memories jsonb
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  acknowledged_count integer := 0;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_memories is null
    or jsonb_typeof(requested_memories) <> 'array'
    or jsonb_array_length(requested_memories) > 100
  then
    perform private.raise_app_error('invalid_ai_memory_attention_request');
  end if;

  if jsonb_array_length(requested_memories) = 0 then
    return 0;
  end if;

  if exists (
    select 1
    from jsonb_array_elements(requested_memories) as requested(value)
    where jsonb_typeof(requested.value) <> 'object'
      or jsonb_typeof(requested.value->'memory_id') <> 'string'
      or jsonb_typeof(requested.value->'memory_updated_at') <> 'string'
  ) then
    perform private.raise_app_error('invalid_ai_memory_attention_request');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if not private.have_all_couple_members_granted_ai_consent(active_couple.id) then
    perform private.raise_app_error('ai_consent_required');
  end if;

  with requested as (
    select
      parsed.memory_id,
      parsed.memory_updated_at
    from jsonb_to_recordset(requested_memories) as parsed(
      memory_id uuid,
      memory_updated_at timestamptz
    )
    where parsed.memory_id is not null
      and parsed.memory_updated_at is not null
  ),
  acknowledgeable as (
    select distinct
      visible_memory.memory_id,
      memory.updated_at
    from public.list_ai_memories() as visible_memory
    join public.ai_memories as memory
      on memory.id = visible_memory.memory_id
    join requested
      on requested.memory_id = visible_memory.memory_id
      and requested.memory_updated_at = memory.updated_at
    where visible_memory.memory_state = 'pending'
      and (
        (
          visible_memory.memory_scope = 'personal'
          and visible_memory.subject_user_id = current_user_id
        )
        or visible_memory.memory_scope = 'couple'
      )
      and not exists (
        select 1
        from public.ai_memory_confirmations as confirmation
        where confirmation.memory_id = visible_memory.memory_id
          and confirmation.user_id = current_user_id
      )
  ),
  saved as (
    insert into public.ai_memory_attention_receipts (
      memory_id,
      couple_id,
      user_id,
      seen_memory_updated_at,
      seen_at
    )
    select
      acknowledgeable.memory_id,
      active_couple.id,
      current_user_id,
      acknowledgeable.updated_at,
      now()
    from acknowledgeable
    on conflict (memory_id, user_id)
    do update
    set
      couple_id = excluded.couple_id,
      seen_memory_updated_at = excluded.seen_memory_updated_at,
      seen_at = excluded.seen_at
    where ai_memory_attention_receipts.seen_memory_updated_at
      is distinct from excluded.seen_memory_updated_at
    returning 1
  )
  select count(*)::integer
  into acknowledged_count
  from saved;

  return acknowledged_count;
exception
  when invalid_text_representation
    or invalid_datetime_format
    or datetime_field_overflow
  then
    perform private.raise_app_error('invalid_ai_memory_attention_request');
    return 0;
end;
$$;

revoke all on table public.ai_memory_attention_receipts
  from public, anon, authenticated;
grant select on table public.ai_memory_attention_receipts
  to authenticated;

revoke execute on function public.get_ai_memory_attention_state()
  from public, anon;
revoke execute on function public.acknowledge_ai_memories(jsonb)
  from public, anon;

grant execute on function public.get_ai_memory_attention_state()
  to authenticated;
grant execute on function public.acknowledge_ai_memories(jsonb)
  to authenticated;
