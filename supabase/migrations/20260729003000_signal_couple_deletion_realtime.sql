create or replace function private.delete_couple_shared_data(
  target_couple_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked_couple_id uuid;
  personalized_question_ids uuid[];
begin
  if target_couple_id is null then
    return;
  end if;

  select c.id
  into locked_couple_id
  from public.couples as c
  where c.id = target_couple_id
  for update;

  if not found then
    return;
  end if;

  select coalesce(array_agg(q.id), array[]::uuid[])
  into personalized_question_ids
  from public.questions as q
  where q.source = 'ai'
    and q.personalized_for_couple_id = locked_couple_id;

  perform private.enqueue_all_couple_storage_objects(locked_couple_id);

  -- Filtered Postgres Changes cannot receive DELETE events. Emit a final
  -- UPDATE so both members' existing couple subscription refreshes to null.
  update public.couples
  set updated_at = greatest(
    clock_timestamp(),
    updated_at + interval '1 microsecond'
  )
  where id = locked_couple_id;

  delete from public.couples
  where id = locked_couple_id;

  delete from public.questions
  where id = any(personalized_question_ids);
end;
$$;

revoke execute on function private.delete_couple_shared_data(uuid)
  from public, anon, authenticated;
