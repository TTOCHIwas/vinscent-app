create or replace function private.has_current_user_ugc_safety_policy_acceptance()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and private.has_current_ugc_safety_policy_acceptance(auth.uid());
$$;

revoke all on function private.has_current_user_ugc_safety_policy_acceptance()
  from public, anon;
grant execute on function private.has_current_user_ugc_safety_policy_acceptance()
  to authenticated;

create or replace function private.enforce_current_user_ugc_safety_policy_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Slot removal bumps revision metadata before deleting the row.
  if tg_op = 'UPDATE' then
    if tg_table_name in (
        'couple_recording_slots',
        'couple_recording_slot_placements'
      )
      and (
        to_jsonb(new) - array[
          'updated_by_user_id',
          'revision',
          'updated_at'
        ]
      ) = (
        to_jsonb(old) - array[
          'updated_by_user_id',
          'revision',
          'updated_at'
        ]
      )
    then
      return new;
    end if;
  end if;

  if auth.uid() is not null
    and not private.has_current_ugc_safety_policy_acceptance(auth.uid())
  then
    perform private.raise_app_error(
      'ugc_safety_policy_acceptance_required'
    );
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_current_user_ugc_safety_policy_acceptance()
  from public, anon, authenticated;

create trigger daily_question_answers_require_ugc_policy
  before insert or update on public.daily_question_answers
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger couple_characters_require_ugc_policy
  before insert or update on public.couple_characters
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger couple_expressions_require_ugc_policy
  before insert or update on public.couple_expressions
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger couple_recordings_require_ugc_policy
  before insert or update on public.couple_recordings
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger couple_current_recordings_require_ugc_policy
  before insert or update on public.couple_current_recordings
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger couple_recording_slots_require_ugc_policy
  before insert or update on public.couple_recording_slots
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger couple_recording_slot_placements_require_ugc_policy
  before insert or update on public.couple_recording_slot_placements
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger story_loop_cards_require_ugc_policy
  before insert or update on public.story_loop_cards
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger ai_focused_question_answers_require_ugc_policy
  before insert or update on public.ai_focused_question_answers
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger ai_user_questions_require_ugc_policy
  before insert or update on public.ai_user_questions
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create trigger couple_calendar_events_require_ugc_policy
  before insert or update on public.couple_calendar_events
  for each row
  execute function private.enforce_current_user_ugc_safety_policy_acceptance();

create or replace function private.enforce_couple_members_ugc_safety_policy_acceptance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or new.status <> 'active' then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.status = 'active' then
    return new;
  end if;

  if not private.has_current_ugc_safety_policy_acceptance(new.user_a_id)
    or not private.has_current_ugc_safety_policy_acceptance(new.user_b_id)
  then
    perform private.raise_app_error(
      'ugc_safety_policy_acceptance_required'
    );
  end if;

  return new;
end;
$$;

revoke all on function private.enforce_couple_members_ugc_safety_policy_acceptance()
  from public, anon, authenticated;

create trigger couples_require_ugc_policy_on_activation
  before insert or update on public.couples
  for each row
  execute function private.enforce_couple_members_ugc_safety_policy_acceptance();

drop policy if exists "couple_characters_storage_insert_member"
  on storage.objects;
drop policy if exists "couple_characters_storage_update_member"
  on storage.objects;
drop policy if exists "couple_recordings_storage_insert_member"
  on storage.objects;
drop policy if exists "couple_recording_artworks_storage_insert_member"
  on storage.objects;
drop policy if exists "story_cards_storage_insert_member"
  on storage.objects;
drop policy if exists "story_cards_storage_update_member"
  on storage.objects;
drop policy if exists "couple_calendar_artworks_storage_insert_member"
  on storage.objects;

create policy "couple_characters_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_character_storage_object(bucket_id, name)
  );

create policy "couple_characters_storage_update_member"
  on storage.objects
  for update
  to authenticated
  using (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_character_storage_object(bucket_id, name)
  )
  with check (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_character_storage_object(bucket_id, name)
  );

create policy "couple_recordings_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_writable_recording_storage_object(
      bucket_id,
      name
    )
  );

create policy "couple_recording_artworks_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_writable_recording_artwork_storage_object(
      bucket_id,
      name
    )
  );

create policy "story_cards_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_writable_story_card_storage_object(
      bucket_id,
      name
    )
  );

create policy "story_cards_storage_update_member"
  on storage.objects
  for update
  to authenticated
  using (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_writable_story_card_storage_object(
      bucket_id,
      name
    )
  )
  with check (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_writable_story_card_storage_object(
      bucket_id,
      name
    )
  );

create policy "couple_calendar_artworks_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.has_current_user_ugc_safety_policy_acceptance()
    and private.is_current_user_writable_calendar_artwork(bucket_id, name)
  );
