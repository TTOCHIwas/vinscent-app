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

  delete from public.couples
  where id = locked_couple_id;

  delete from public.questions
  where id = any(personalized_question_ids);
end;
$$;

create or replace function public.delete_disconnected_couple_archive_now()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  archived_couple_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select c.id
  into archived_couple_id
  from public.couples as c
  where c.status = 'disconnected'
    and c.archive_expires_at is not null
    and c.archive_expires_at > now()
    and (c.user_a_id = current_user_id or c.user_b_id = current_user_id)
  order by c.created_at desc
  limit 1
  for update;

  if not found then
    return;
  end if;

  perform private.delete_couple_shared_data(archived_couple_id);
end;
$$;

create or replace function public.purge_expired_disconnected_couples(
  batch_limit integer default 50
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer := 0;
  archived_couple_id uuid;
begin
  for archived_couple_id in
    select c.id
    from public.couples as c
    where c.status = 'disconnected'
      and c.archive_expires_at is not null
      and c.archive_expires_at <= now()
    order by c.archive_expires_at
    limit greatest(coalesce(batch_limit, 50), 1)
    for update skip locked
  loop
    perform private.delete_couple_shared_data(archived_couple_id);
    deleted_count := deleted_count + 1;
  end loop;

  return deleted_count;
end;
$$;

revoke execute on function private.delete_couple_shared_data(uuid)
  from public, anon, authenticated;

revoke execute on function public.delete_disconnected_couple_archive_now()
  from public, anon;
revoke execute on function public.purge_expired_disconnected_couples(integer)
  from public, anon, authenticated;

grant execute on function public.delete_disconnected_couple_archive_now()
  to authenticated;
grant execute on function public.purge_expired_disconnected_couples(integer)
  to service_role;
