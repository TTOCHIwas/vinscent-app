create or replace function public.delete_today_story_loop_card(
  expected_revision integer
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  current_couple_date date;
  target_story_loop public.daily_story_loops%rowtype;
  target_card public.story_loop_cards%rowtype;
  remaining_card_count integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if expected_revision is null or expected_revision < 1 then
    perform private.raise_app_error('story_card_revision_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  current_couple_date := private.current_date_in_timezone(active_couple.timezone);

  perform pg_advisory_xact_lock(
    hashtext('story_loop_card_write'),
    hashtext(active_couple.id::text || ':' || current_couple_date::text)
  );

  select *
  into target_story_loop
  from public.daily_story_loops as dsl
  where dsl.couple_id = active_couple.id
    and dsl.couple_date = current_couple_date
  for update;

  if not found then
    perform private.raise_app_error('story_card_not_found');
  end if;

  if target_story_loop.story_edit_locked_at is not null
    or target_story_loop.status <> 'waiting_partner_card'
    or exists (
      select 1
      from public.daily_questions as dq
      where dq.story_loop_id = target_story_loop.id
    )
  then
    perform private.raise_app_error('story_card_locked');
  end if;

  select *
  into target_card
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id
    and slc.author_user_id = current_user_id
  for update;

  if not found then
    perform private.raise_app_error('story_card_not_found');
  end if;

  if target_card.revision <> expected_revision then
    perform private.raise_app_error('story_card_revision_conflict');
  end if;

  delete from public.story_loop_cards
  where id = target_card.id;

  select count(*)::integer
  into remaining_card_count
  from public.story_loop_cards as slc
  where slc.story_loop_id = target_story_loop.id;

  if remaining_card_count = 0 then
    update public.daily_story_loops
    set updated_at = now()
    where id = target_story_loop.id;

    delete from public.daily_story_loops
    where id = target_story_loop.id;
  else
    update public.daily_story_loops as dsl
    set status = 'waiting_partner_card'
    where dsl.id = target_story_loop.id;
  end if;
end;
$$;
