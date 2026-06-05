create table public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint user_push_tokens_token_length
    check (char_length(btrim(token)) between 20 and 4096),
  constraint user_push_tokens_platform_check
    check (platform in ('android', 'ios'))
);

create unique index user_push_tokens_token_unique
  on public.user_push_tokens (token);

create index user_push_tokens_user_active_idx
  on public.user_push_tokens (user_id, is_active, last_seen_at desc);

alter table public.user_push_tokens enable row level security;

create trigger user_push_tokens_set_updated_at
  before update on public.user_push_tokens
  for each row
  execute function public.set_updated_at();

create policy "user_push_tokens_select_own"
  on public.user_push_tokens
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create table public.push_notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  notification_type text not null,
  source_id uuid,
  receiver_user_id uuid references auth.users(id) on delete set null,
  target_token_count integer not null default 0,
  success_count integer not null default 0,
  failure_count integer not null default 0,
  status text not null,
  error_message text,
  created_at timestamptz not null default now(),

  constraint push_notification_deliveries_notification_type_check
    check (notification_type in ('couple_expression')),
  constraint push_notification_deliveries_status_check
    check (status in ('sent', 'partial_failure', 'failed', 'skipped')),
  constraint push_notification_deliveries_counts_non_negative
    check (
      target_token_count >= 0
      and success_count >= 0
      and failure_count >= 0
    )
);

create index push_notification_deliveries_receiver_created_idx
  on public.push_notification_deliveries (receiver_user_id, created_at desc);

create index push_notification_deliveries_source_idx
  on public.push_notification_deliveries (notification_type, source_id);

alter table public.push_notification_deliveries enable row level security;

create or replace function public.upsert_user_push_token(
  push_token text,
  push_platform text
)
returns table (
  id uuid,
  user_id uuid,
  token text,
  platform text,
  is_active boolean,
  last_seen_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_token text := btrim(push_token);
  normalized_platform text := lower(btrim(push_platform));
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if normalized_token is null
    or char_length(normalized_token) < 20
    or char_length(normalized_token) > 4096
  then
    perform private.raise_app_error('invalid_push_token');
  end if;

  if normalized_platform is null
    or normalized_platform not in ('android', 'ios')
  then
    perform private.raise_app_error('invalid_push_platform');
  end if;

  insert into public.user_push_tokens (
    user_id,
    token,
    platform,
    is_active,
    last_seen_at
  )
  values (
    current_user_id,
    normalized_token,
    normalized_platform,
    true,
    now()
  )
  on conflict (token)
  do update
    set
      user_id = excluded.user_id,
      platform = excluded.platform,
      is_active = true,
      last_seen_at = excluded.last_seen_at
  returning
    public.user_push_tokens.id,
    public.user_push_tokens.user_id,
    public.user_push_tokens.token,
    public.user_push_tokens.platform,
    public.user_push_tokens.is_active,
    public.user_push_tokens.last_seen_at,
    public.user_push_tokens.created_at,
    public.user_push_tokens.updated_at
  into
    id,
    user_id,
    token,
    platform,
    is_active,
    last_seen_at,
    created_at,
    updated_at;

  return next;
end;
$$;

create or replace function public.deactivate_user_push_token(
  push_token text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  normalized_token text := btrim(push_token);
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if normalized_token is null or normalized_token = '' then
    return;
  end if;

  update public.user_push_tokens
  set
    is_active = false,
    last_seen_at = now()
  where user_push_tokens.user_id = current_user_id
    and user_push_tokens.token = normalized_token;
end;
$$;

revoke execute on function public.upsert_user_push_token(text, text)
  from public, anon;
revoke execute on function public.deactivate_user_push_token(text)
  from public, anon;

grant execute on function public.upsert_user_push_token(text, text)
  to authenticated;
grant execute on function public.deactivate_user_push_token(text)
  to authenticated;
