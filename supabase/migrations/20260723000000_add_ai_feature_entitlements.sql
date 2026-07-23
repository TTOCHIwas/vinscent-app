create table public.ai_feature_entitlements (
  couple_id uuid not null references public.couples(id) on delete cascade,
  feature_key text not null,
  source text not null,
  is_enabled boolean not null default true,
  granted_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  primary key (couple_id, feature_key),
  constraint ai_feature_entitlements_feature_key_check
    check (feature_key ~ '^[a-z][a-z0-9_]{2,63}$'),
  constraint ai_feature_entitlements_source_check
    check (source ~ '^[a-z][a-z0-9_]{2,63}$')
);

alter table public.ai_feature_entitlements enable row level security;

create trigger ai_feature_entitlements_set_updated_at
  before update on public.ai_feature_entitlements
  for each row
  execute function public.set_updated_at();

revoke all on table public.ai_feature_entitlements
  from public, anon, authenticated;
grant all on table public.ai_feature_entitlements to service_role;

create or replace function private.has_ai_feature_entitlement(
  requested_couple_id uuid,
  requested_feature_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.ai_feature_entitlements as aife
    where aife.couple_id = requested_couple_id
      and aife.feature_key = btrim(requested_feature_key)
      and aife.is_enabled
      and (
        aife.expires_at is null
        or aife.expires_at > now()
      )
  );
$$;

revoke execute on function private.has_ai_feature_entitlement(uuid, text)
  from public, anon, authenticated;
grant execute on function private.has_ai_feature_entitlement(uuid, text)
  to service_role;

create or replace function public.get_ai_learning_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  learning_progress jsonb;
  visible_memories jsonb;
  enabled_features jsonb;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();
  learning_progress := public.get_ai_learning_progress();

  select coalesce(
    jsonb_agg(aife.feature_key order by aife.feature_key),
    '[]'::jsonb
  )
  into enabled_features
  from public.ai_feature_entitlements as aife
  where aife.couple_id = active_couple.id
    and aife.is_enabled
    and (
      aife.expires_at is null
      or aife.expires_at > now()
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'memory_id', memories.memory_id,
        'scope', memories.memory_scope,
        'subject_user_id', memories.subject_user_id,
        'kind', memories.memory_kind,
        'learning_domain', aim.learning_domain,
        'evidence_type', aim.evidence_type,
        'statement', memories.memory_statement,
        'confidence', memories.memory_confidence,
        'state', memories.memory_state,
        'my_decision', my_confirmation.decision,
        'confirmed_count', coalesce(confirmations.confirmed_count, 0),
        'required_confirmation_count', case
          when memories.memory_scope = 'personal' then 1
          else 2
        end,
        'can_confirm',
          (learning_progress->>'ai_enabled')::boolean
          and memories.memory_state = 'pending'
          and (
            memories.memory_scope = 'couple'
            or memories.subject_user_id = current_user_id
          )
          and my_confirmation.decision is null,
        'evidence_count', cardinality(memories.evidence_answer_ids),
        'created_at', memories.memory_created_at,
        'updated_at', memories.memory_updated_at
      )
      order by memories.memory_updated_at desc, memories.memory_id
    ),
    '[]'::jsonb
  )
  into visible_memories
  from public.list_ai_memories() as memories
  join public.ai_memories as aim on aim.id = memories.memory_id
  left join lateral (
    select aimc.decision
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = memories.memory_id
      and aimc.user_id = current_user_id
  ) as my_confirmation on true
  left join lateral (
    select
      (
        count(*) filter (
          where aimc.decision = 'confirmed'
        )
      )::integer as confirmed_count
    from public.ai_memory_confirmations as aimc
    where aimc.memory_id = memories.memory_id
  ) as confirmations on true;

  return jsonb_build_object(
    'progress', learning_progress,
    'enabled_features', enabled_features,
    'memories', visible_memories
  );
end;
$$;
