begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '51000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'relationship-owner@example.test',
    now(),
    now()
  ),
  (
    '51000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'relationship-setup@example.test',
    now(),
    now()
  ),
  (
    '51000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'relationship-editor-a@example.test',
    now(),
    now()
  ),
  (
    '51000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'relationship-editor-b@example.test',
    now(),
    now()
  );

insert into public.profiles (id, display_name, birth_date)
values
  ('51000000-0000-0000-0000-000000000001', 'Owner', '1990-01-01'),
  ('51000000-0000-0000-0000-000000000002', 'Setup', '1990-01-01'),
  ('51000000-0000-0000-0000-000000000003', 'EditorA', '1990-01-01'),
  ('51000000-0000-0000-0000-000000000004', 'EditorB', '1990-01-01');

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  character_setup_status,
  timezone,
  status,
  connected_at
)
values
  (
    '52000000-0000-0000-0000-000000000001',
    'SETUP1',
    '51000000-0000-0000-0000-000000000001',
    '51000000-0000-0000-0000-000000000002',
    null,
    'pending',
    'Asia/Seoul',
    'active',
    now()
  ),
  (
    '52000000-0000-0000-0000-000000000002',
    'EDIT01',
    '51000000-0000-0000-0000-000000000003',
    '51000000-0000-0000-0000-000000000004',
    '2024-01-01',
    'custom',
    'Asia/Seoul',
    'active',
    now()
  );

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '53000000-0000-0000-0000-000000000001',
  '52000000-0000-0000-0000-000000000002',
  '2024-02-01',
  'waiting_partner_card'
);

select has_function(
  'public',
  'cancel_initial_couple_setup',
  array[]::text[],
  'initial couple setup exposes a dedicated cancellation boundary'
);

select has_function(
  'public',
  'update_relationship_start_date',
  array['date']::text[],
  'relationship start date remains editable through its existing boundary'
);

select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  $$ select public.cancel_initial_couple_setup() $$,
  'P0001',
  'initial_setup_cancel_not_available',
  'the inviting member cannot cancel setup owned by the code-entering member'
);

reset role;
select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select lives_ok(
  $$ select public.cancel_initial_couple_setup() $$,
  'the code-entering member can cancel incomplete setup'
);

reset role;

select results_eq(
  $$
    select status
    from public.couples
    where id = '52000000-0000-0000-0000-000000000001'
  $$,
  $$ values ('cancelled'::text) $$,
  'cancelling setup closes the active couple without creating an archive'
);

select set_config(
  'request.jwt.claim.sub',
  '51000000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select lives_ok(
  $$ select public.update_relationship_start_date('2023-12-01'::date) $$,
  'moving the relationship date earlier preserves all existing records'
);

select throws_ok(
  $$ select public.update_relationship_start_date('2024-03-01'::date) $$,
  'P0001',
  'relationship_date_conflicts_with_existing_records',
  'moving the relationship date past an existing record is rejected'
);

reset role;

select results_eq(
  $$
    select relationship_start_date
    from public.couples
    where id = '52000000-0000-0000-0000-000000000002'
  $$,
  $$ values ('2023-12-01'::date) $$,
  'a rejected correction leaves the last valid relationship date unchanged'
);

select * from finish();
rollback;
