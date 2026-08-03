begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(35);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '19000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'blocker@example.test',
    now(),
    now()
  ),
  (
    '19000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'blocked@example.test',
    now(),
    now()
  );

insert into public.profiles (id, display_name, birth_date)
values
  (
    '19000000-0000-0000-0000-000000000001',
    '차단자',
    (current_date - interval '20 years')::date
  ),
  (
    '19000000-0000-0000-0000-000000000002',
    '상대방',
    (current_date - interval '20 years')::date
  );

insert into public.couples (
  id,
  invite_code,
  user_a_id,
  user_b_id,
  relationship_start_date,
  character_setup_status,
  status,
  connected_at
)
values (
  '29000000-0000-0000-0000-000000000001',
  'BLOCK1',
  '19000000-0000-0000-0000-000000000001',
  '19000000-0000-0000-0000-000000000002',
  current_date - 100,
  'custom',
  'active',
  now() - interval '100 days'
);

select ok(
  to_regclass('public.user_blocks') is not null,
  'directed user blocks are stored independently from a couple archive'
);
select ok(
  to_regclass('public.user_safety_states') is not null,
  'each user has a bounded realtime safety revision signal'
);
select has_column(
  'public',
  'couples',
  'disconnect_reason',
  'a disconnected couple preserves why its archive is hidden'
);
select ok(
  to_regprocedure('public.block_current_partner()') is not null,
  'an authenticated user can block only the current partner'
);
select ok(
  to_regprocedure('public.unblock_user(uuid)') is not null,
  'a blocker can explicitly remove one block'
);
select ok(
  to_regprocedure('public.list_blocked_users()') is not null,
  'the app can list blocks created by the current user'
);
select ok(
  to_regprocedure('public.list_reconnectable_couple_archives()') is not null,
  'the app can discover hidden archives only after every block is removed'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.user_blocks',
    'SELECT'
  ),
  'authenticated clients cannot enumerate block relationships directly'
);

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$ select public.block_current_partner() $$,
  'blocking the current partner succeeds'
);
select lives_ok(
  $$ select public.delete_disconnected_couple_archive_now() $$,
  'the ordinary archive deletion flow cannot remove a hidden blocked archive'
);

reset role;

select is(
  (
    select count(*)
    from public.user_blocks
    where blocker_user_id = '19000000-0000-0000-0000-000000000001'
      and blocked_user_id = '19000000-0000-0000-0000-000000000002'
  ),
  1::bigint,
  'the directed block is persisted'
);
select is(
  (
    select status
    from public.couples
    where id = '29000000-0000-0000-0000-000000000001'
  ),
  'disconnected',
  'blocking ends the active couple connection'
);
select is(
  (
    select disconnect_reason
    from public.couples
    where id = '29000000-0000-0000-0000-000000000001'
  ),
  'user_block',
  'the archive remains hidden after the block itself is removed'
);
select ok(
  (
    select archive_expires_at > now()
      and archive_expires_at <= now() + interval '31 days'
    from public.couples
    where id = '29000000-0000-0000-0000-000000000001'
  ),
  'blocked shared data keeps the existing 30 day deletion window'
);
select is(
  (
    select count(*)
    from public.couple_reconnect_invites
    where couple_id = '29000000-0000-0000-0000-000000000001'
  ),
  0::bigint,
  'blocking never leaves a reconnect invitation active'
);
select is(
  (
    select count(*)
    from public.user_safety_states
    where user_id in (
      '19000000-0000-0000-0000-000000000001',
      '19000000-0000-0000-0000-000000000002'
    )
  ),
  2::bigint,
  'blocking signals both affected app sessions'
);

set local role authenticated;

select is(
  (select count(*) from public.get_current_couple_context()),
  0::bigint,
  'the blocker no longer receives the blocked couple context'
);

reset role;

select is(
  private.is_readable_couple_member(
    '29000000-0000-0000-0000-000000000001',
    '19000000-0000-0000-0000-000000000001'
  ),
  false,
  'the blocker cannot read couple-scoped rows'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.couples',
    'SELECT'
  ),
  'clients cannot query hidden archive metadata directly'
);

select is(
  private.is_current_user_character_storage_object(
    'couple-characters',
    '29000000-0000-0000-0000-000000000001/current.png'
  ),
  false,
  'the blocker cannot bypass the archive through character storage'
);
select is(
  private.is_current_user_readable_recording_storage_object(
    'couple-recordings',
    '29000000-0000-0000-0000-000000000001/recordings/example.m4a'
  ),
  false,
  'the blocker cannot bypass the archive through recording storage'
);

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.get_current_couple_context()),
  0::bigint,
  'the blocked partner no longer receives the couple context'
);

reset role;

select is(
  private.is_readable_couple_member(
    '29000000-0000-0000-0000-000000000001',
    '19000000-0000-0000-0000-000000000002'
  ),
  false,
  'the blocked partner cannot read couple-scoped rows'
);

set local role authenticated;

select is(
  (select count(*) from public.list_blocked_users()),
  0::bigint,
  'a block is visible only to the user who created it'
);
select is(
  public.unblock_user('19000000-0000-0000-0000-000000000001'),
  false,
  'the blocked partner cannot remove the opposite directed block'
);

reset role;

select is(
  (select count(*) from public.user_blocks),
  1::bigint,
  'an unauthorized unblock attempt leaves the block intact'
);

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select results_eq(
  $$
    select user_id, display_name
    from public.list_blocked_users()
  $$,
  $$
    values (
      '19000000-0000-0000-0000-000000000002'::uuid,
      '상대방'::text
    )
  $$,
  'the blocker can identify the user to unblock'
);
select is(
  public.unblock_user('19000000-0000-0000-0000-000000000002'),
  true,
  'the blocker can remove the directed block'
);

reset role;

select is(
  (select count(*) from public.user_blocks),
  0::bigint,
  'unblocking removes only the safety deny relation'
);
select is(
  (
    select min(revision)
    from public.user_safety_states
    where user_id in (
      '19000000-0000-0000-0000-000000000001',
      '19000000-0000-0000-0000-000000000002'
    )
  ),
  2::bigint,
  'unblocking silently refreshes both affected app sessions'
);

set local role authenticated;

select is(
  (select count(*) from public.get_current_couple_context()),
  0::bigint,
  'unblocking does not automatically restore the blocker relationship'
);

reset role;

select is(
  private.is_readable_couple_member(
    '29000000-0000-0000-0000-000000000001',
    '19000000-0000-0000-0000-000000000001'
  ),
  false,
  'unblocking does not automatically restore shared data access'
);

set local role authenticated;

select results_eq(
  $$
    select couple_id, partner_user_id, partner_display_name
    from public.list_reconnectable_couple_archives()
  $$,
  $$
    values (
      '29000000-0000-0000-0000-000000000001'::uuid,
      '19000000-0000-0000-0000-000000000002'::uuid,
      '상대방'::text
    )
  $$,
  'the blocker can explicitly choose the former archive for reconnection'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '19000000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.get_current_couple_context()),
  0::bigint,
  'unblocking does not automatically restore the former partner relationship'
);
select results_eq(
  $$
    select couple_id, partner_user_id, partner_display_name
    from public.list_reconnectable_couple_archives()
  $$,
  $$
    values (
      '29000000-0000-0000-0000-000000000001'::uuid,
      '19000000-0000-0000-0000-000000000001'::uuid,
      '차단자'::text
    )
  $$,
  'both former members require an explicit reconnect action'
);

select * from finish();
rollback;
