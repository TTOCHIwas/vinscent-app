create or replace function public.delete_disconnected_couple_archive_now()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  archived_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select c.*
  into archived_couple
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

  perform private.delete_couple_character_storage_objects(archived_couple.id);
  perform private.delete_couple_recording_storage_objects(archived_couple.id);
  perform private.enqueue_couple_story_card_storage_objects(archived_couple.id);

  delete from public.couples
  where id = archived_couple.id;
end;
$$;

revoke execute on function public.delete_disconnected_couple_archive_now()
  from public, anon;

grant execute on function public.delete_disconnected_couple_archive_now()
  to authenticated;
