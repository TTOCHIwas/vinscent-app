begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '15000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'recording-read-a@example.test',
    now(),
    now()
  ),
  (
    '15000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'recording-read-b@example.test',
    now(),
    now()
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  status,
  connected_at,
  character_setup_status
)
values (
  '25000000-0000-0000-0000-000000000001',
  'RECORDR1',
  '15000000-0000-0000-0000-000000000001',
  '15000000-0000-0000-0000-000000000002',
  current_date - 30,
  'active',
  now(),
  'default'
);

insert into public.couple_recording_slot_settings (couple_id, slot_limit)
values ('25000000-0000-0000-0000-000000000001', 2);

insert into public.couple_recordings (
  id,
  couple_id,
  sender_user_id,
  storage_path,
  duration_ms,
  created_at
)
values
  (
    '35000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000001',
    '15000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000001/recordings/'
      || '35000000-0000-0000-0000-000000000001.m4a',
    8000,
    now() - interval '3 minutes'
  ),
  (
    '35000000-0000-0000-0000-000000000002',
    '25000000-0000-0000-0000-000000000001',
    '15000000-0000-0000-0000-000000000002',
    '25000000-0000-0000-0000-000000000001/recordings/'
      || '35000000-0000-0000-0000-000000000002.m4a',
    9000,
    now() - interval '2 minutes'
  ),
  (
    '35000000-0000-0000-0000-000000000003',
    '25000000-0000-0000-0000-000000000001',
    '15000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000001/recordings/'
      || '35000000-0000-0000-0000-000000000003.m4a',
    10000,
    now() - interval '1 minute'
  );

insert into public.couple_current_recordings (
  couple_id,
  recording_id,
  updated_by_user_id,
  revision
)
values (
  '25000000-0000-0000-0000-000000000001',
  '35000000-0000-0000-0000-000000000003',
  '15000000-0000-0000-0000-000000000001',
  4
);

insert into public.couple_recording_slots (
  id,
  couple_id,
  slot_index,
  title,
  recording_id,
  created_by_user_id,
  updated_by_user_id,
  revision,
  artwork_preview_path,
  artwork_data_path,
  artwork_revision
)
values
  (
    '55000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000001',
    1,
    '첫 녹음',
    '35000000-0000-0000-0000-000000000001',
    '15000000-0000-0000-0000-000000000001',
    '15000000-0000-0000-0000-000000000002',
    3,
    '25000000-0000-0000-0000-000000000001/slots/'
      || '55000000-0000-0000-0000-000000000001/artworks/'
      || '65000000-0000-0000-0000-000000000001/preview.webp',
    '25000000-0000-0000-0000-000000000001/slots/'
      || '55000000-0000-0000-0000-000000000001/artworks/'
      || '65000000-0000-0000-0000-000000000001/drawing.json.gz',
    2
  ),
  (
    '55000000-0000-0000-0000-000000000002',
    '25000000-0000-0000-0000-000000000001',
    2,
    '두 번째',
    '35000000-0000-0000-0000-000000000002',
    '15000000-0000-0000-0000-000000000002',
    '15000000-0000-0000-0000-000000000002',
    1,
    null,
    null,
    null
  );

insert into public.couple_recording_slot_placements (
  slot_id,
  couple_id,
  normalized_x,
  normalized_y,
  updated_by_user_id,
  revision
)
values
  (
    '55000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000001',
    0.2,
    0.3,
    '15000000-0000-0000-0000-000000000001',
    2
  ),
  (
    '55000000-0000-0000-0000-000000000002',
    '25000000-0000-0000-0000-000000000001',
    0.7,
    0.8,
    '15000000-0000-0000-0000-000000000002',
    1
  );

select set_config(
  'request.jwt.claim.sub',
  '15000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select is(
  (select couple_id from public.get_current_couple_recording()),
  '25000000-0000-0000-0000-000000000001'::uuid,
  'current recording belongs to the readable couple'
);
select is(
  (select slot_limit from public.get_current_couple_recording()),
  2,
  'current recording response includes the unlocked slot limit'
);
select is(
  (select current_recording_id from public.get_current_couple_recording()),
  '35000000-0000-0000-0000-000000000003'::uuid,
  'current recording response selects the active recording'
);
select is(
  (select current_duration_ms from public.get_current_couple_recording()),
  10000,
  'current recording response includes its duration'
);
select is(
  (select count(*) from public.list_couple_recording_slots()),
  2::bigint,
  'slot list returns both saved slots'
);
select is(
  (
    select title
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  '첫 녹음',
  'slot list preserves the title'
);
select is(
  (
    select recording_path
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  '25000000-0000-0000-0000-000000000001/recordings/'
    || '35000000-0000-0000-0000-000000000001.m4a',
  'slot list includes the recording storage path'
);
select is(
  (
    select artwork_preview_path
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  '25000000-0000-0000-0000-000000000001/slots/'
    || '55000000-0000-0000-0000-000000000001/artworks/'
    || '65000000-0000-0000-0000-000000000001/preview.webp',
  'slot list includes the artwork preview path'
);
select is(
  (
    select artwork_data_path
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  '25000000-0000-0000-0000-000000000001/slots/'
    || '55000000-0000-0000-0000-000000000001/artworks/'
    || '65000000-0000-0000-0000-000000000001/drawing.json.gz',
  'slot list includes the artwork drawing path'
);
select is(
  (
    select artwork_revision
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  2,
  'slot list includes the artwork revision'
);
select is(
  (
    select placement_normalized_x
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  0.2::double precision,
  'slot list includes the horizontal placement'
);
select is(
  (
    select placement_normalized_y
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  0.3::double precision,
  'slot list includes the vertical placement'
);
select is(
  (
    select placement_z_index
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'first placement receives the lowest z-index'
);
select is(
  (
    select placement_z_index
    from public.list_couple_recording_slots()
    where slot_id = '55000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'second placement is layered above the first'
);

select * from finish();
rollback;
