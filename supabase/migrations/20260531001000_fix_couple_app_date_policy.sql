create or replace function private.current_app_date()
returns date
language sql
stable
security definer
set search_path = ''
as $$
  select (now() at time zone 'Asia/Seoul')::date;
$$;

alter table public.couples
  drop constraint if exists couples_relationship_start_date_not_future;

alter table public.couples
  add constraint couples_relationship_start_date_not_future
  check (
    relationship_start_date is null
    or relationship_start_date <= private.current_app_date()
  );

create or replace function private.update_relationship_start_date(
  start_date date
)
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  target_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if start_date is null or start_date > private.current_app_date() then
    perform private.raise_app_error('relationship_date_in_future');
  end if;

  perform pg_advisory_xact_lock(
    hashtext('couple_user'),
    hashtext(current_user_id::text)
  );

  select *
  into target_couple
  from public.couples
  where status = 'active'
    and (user_a_id = current_user_id or user_b_id = current_user_id)
  for update;

  if not found then
    perform private.raise_app_error('active_couple_required');
  end if;

  update public.couples
  set relationship_start_date = start_date
  where id = target_couple.id
  returning * into target_couple;

  return target_couple;
end;
$$;

revoke execute on function private.current_app_date()
  from public, anon, authenticated;
revoke execute on function private.update_relationship_start_date(date)
  from public, anon, authenticated;
