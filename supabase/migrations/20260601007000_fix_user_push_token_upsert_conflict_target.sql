do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.user_push_tokens'::regclass
      and conname = 'user_push_tokens_token_unique'
  ) then
    alter table public.user_push_tokens
      add constraint user_push_tokens_token_unique
      unique using index user_push_tokens_token_unique;
  end if;
end;
$$;

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
  on conflict on constraint user_push_tokens_token_unique
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

revoke execute on function public.upsert_user_push_token(text, text)
  from public, anon;

grant execute on function public.upsert_user_push_token(text, text)
  to authenticated;
