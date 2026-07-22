begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'daily_story_loops'
  ),
  'daily story loops publish realtime changes'
);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'story_loop_cards'
  ),
  'story loop cards publish realtime changes'
);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'daily_questions'
  ),
  'daily questions publish realtime changes'
);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '15000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'story-realtime-a@example.test',
    now(),
    now()
  ),
  (
    '15000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'story-realtime-b@example.test',
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
  'STORYRT1',
  '15000000-0000-0000-0000-000000000001',
  '15000000-0000-0000-0000-000000000002',
  current_date - 30,
  'active',
  now(),
  'default'
);

insert into public.daily_story_loops (
  id,
  couple_id,
  couple_date,
  status
)
values (
  '35000000-0000-0000-0000-000000000001',
  '25000000-0000-0000-0000-000000000001',
  private.current_date_in_timezone('Asia/Seoul'),
  'waiting_partner_card'
);

insert into public.story_loop_cards (
  id,
  story_loop_id,
  couple_id,
  couple_date,
  author_user_id,
  preview_path,
  scene_data_path,
  has_drawing,
  revision
)
values (
  '45000000-0000-0000-0000-000000000001',
  '35000000-0000-0000-0000-000000000001',
  '25000000-0000-0000-0000-000000000001',
  private.current_date_in_timezone('Asia/Seoul'),
  '15000000-0000-0000-0000-000000000001',
  '25000000-0000-0000-0000-000000000001/loops/'
    || private.current_date_in_timezone('Asia/Seoul')::text
    || '/15000000-0000-0000-0000-000000000001/preview.png',
  '25000000-0000-0000-0000-000000000001/loops/'
    || private.current_date_in_timezone('Asia/Seoul')::text
    || '/15000000-0000-0000-0000-000000000001/scene.json',
  true,
  1
);

create temporary table story_loop_realtime_updates (
  loop_id uuid not null
);

create function pg_temp.capture_story_loop_realtime_update()
returns trigger
language plpgsql
as $$
begin
  insert into story_loop_realtime_updates (loop_id)
  values (new.id);
  return new;
end;
$$;

create trigger capture_story_loop_realtime_update
  after update on public.daily_story_loops
  for each row
  execute function pg_temp.capture_story_loop_realtime_update();

select set_config(
  'request.jwt.claim.sub',
  '15000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$select public.delete_today_story_loop_card(1)$$,
  'a member can delete the final editable story card'
);

reset role;

select is(
  (
    select count(*)
    from story_loop_realtime_updates
    where loop_id = '35000000-0000-0000-0000-000000000001'
  ),
  1::bigint,
  'final card deletion emits a filterable story loop update'
);

select is(
  (
    select count(*)
    from public.story_loop_cards
    where id = '45000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'final card deletion removes the card'
);

select is(
  (
    select count(*)
    from public.daily_story_loops
    where id = '35000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'final card deletion still removes the empty story loop'
);

select * from finish();

rollback;
