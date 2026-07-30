create or replace function private.enforce_profile_minimum_age()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.birth_date > (
    private.current_app_date() - interval '14 years'
  )::date then
    perform private.raise_app_error('minimum_age_required');
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_profile_minimum_age()
  from public, anon, authenticated;

drop trigger if exists profiles_enforce_minimum_age
  on public.profiles;

create trigger profiles_enforce_minimum_age
  before insert or update of birth_date
  on public.profiles
  for each row
  execute function private.enforce_profile_minimum_age();
