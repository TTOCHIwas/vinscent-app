drop policy if exists "couple_characters_select_member"
  on public.couple_characters;
drop policy if exists "couple_characters_storage_select_member"
  on storage.objects;
drop policy if exists "couple_characters_storage_insert_member"
  on storage.objects;
drop policy if exists "couple_characters_storage_update_member"
  on storage.objects;

create policy "couple_characters_select_member"
  on public.couple_characters
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.couples as c
      where c.id = couple_id
        and c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
    )
  );

create policy "couple_characters_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'couple-characters'
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and name in (
          c.id::text || '/current.png',
          c.id::text || '/current.json'
        )
    )
  );

create policy "couple_characters_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'couple-characters'
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and name in (
          c.id::text || '/current.png',
          c.id::text || '/current.json'
        )
    )
  );

create policy "couple_characters_storage_update_member"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'couple-characters'
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and name in (
          c.id::text || '/current.png',
          c.id::text || '/current.json'
        )
    )
  )
  with check (
    bucket_id = 'couple-characters'
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and name in (
          c.id::text || '/current.png',
          c.id::text || '/current.json'
        )
    )
  );
