create or replace function private.cancel_initial_couple_setup()
returns void
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

  if not found
    or target_couple.user_b_id <> current_user_id
    or target_couple.relationship_start_date is not null
  then
    perform private.raise_app_error('initial_setup_cancel_not_available');
  end if;

  update public.couples
  set status = 'cancelled'
  where id = target_couple.id;
end;
$$;

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
  current_couple_date date;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
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

  current_couple_date := private.current_date_in_timezone(
    target_couple.timezone
  );
  if start_date is null or start_date > current_couple_date then
    perform private.raise_app_error('relationship_date_in_future');
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

  if target_couple.relationship_start_date is not null
    and start_date > target_couple.relationship_start_date
    and (
      exists (
        select 1
        from public.daily_story_loops as dsl
        where dsl.couple_id = target_couple.id
          and dsl.couple_date < start_date
      )
      or exists (
        select 1
        from public.daily_questions as dq
        where dq.couple_id = target_couple.id
          and dq.assigned_date < start_date
      )
      or exists (
        select 1
        from public.couple_calendar_events as cce
        where cce.couple_id = target_couple.id
          and cce.event_date < start_date
      )
    )
  then
    perform private.raise_app_error(
      'relationship_date_conflicts_with_existing_records'
    );
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

create or replace function public.cancel_initial_couple_setup()
returns void
language sql
security definer
set search_path = ''
as $$
  select private.cancel_initial_couple_setup();
$$;

revoke execute on function private.cancel_initial_couple_setup()
  from public, anon, authenticated;
revoke execute on function public.cancel_initial_couple_setup()
  from public, anon;

grant execute on function public.cancel_initial_couple_setup()
  to authenticated;
