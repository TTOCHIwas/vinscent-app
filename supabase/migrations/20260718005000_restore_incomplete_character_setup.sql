update public.couples as c
set character_setup_status = 'pending'
where c.status = 'active'
  and c.relationship_start_date is null
  and c.character_setup_status = 'default'
  and not exists (
    select 1
    from public.couple_characters as cc
    where cc.couple_id = c.id
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
  should_restore_character_setup boolean;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if start_date is null or start_date > current_date then
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

  should_restore_character_setup :=
    target_couple.relationship_start_date is null
    and target_couple.character_setup_status = 'default'
    and not exists (
      select 1
      from public.couple_characters as cc
      where cc.couple_id = target_couple.id
    );

  if (target_couple.character_setup_status = 'pending'
      or should_restore_character_setup)
    and target_couple.user_b_id <> current_user_id
  then
    perform private.raise_app_error('initial_setup_owner_required');
  end if;

  update public.couples
  set
    relationship_start_date = start_date,
    character_setup_status = case
      when should_restore_character_setup then 'pending'
      else target_couple.character_setup_status
    end
  where id = target_couple.id
  returning * into target_couple;

  return target_couple;
end;
$$;
