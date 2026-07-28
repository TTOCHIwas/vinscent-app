begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '19100000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'reconnect-a@example.test',
    now(),
    now()
  ),
  (
    '19100000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'reconnect-b@example.test',
    now(),
    now()
  ),
  (
    '19100000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'new-partner@example.test',
    now(),
    now()
  );

insert into public.profiles (id, display_name, birth_date)
values
  (
    '19100000-0000-0000-0000-000000000001',
    '사용자A',
    (current_date - interval '20 years')::date
  ),
  (
    '19100000-0000-0000-0000-000000000002',
    '사용자B',
    (current_date - interval '20 years')::date
  ),
  (
    '19100000-0000-0000-0000-000000000003',
    '새상대',
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
  '29100000-0000-0000-0000-000000000001',
  'RECON1',
  '19100000-0000-0000-0000-000000000001',
  '19100000-0000-0000-0000-000000000002',
  current_date - 100,
  'custom',
  'active',
  now() - interval '100 days'
);

create temporary table captured_reconnect_invite (
  couple_id uuid not null,
  invite_code text not null
);

create temporary table captured_new_invite (
  couple_id uuid not null,
  invite_code text not null
);

select ok(
  to_regprocedure(
    'public.create_couple_archive_reconnect_invite(uuid)'
  ) is not null,
  'hidden archives have a dedicated explicit reconnect boundary'
);

select set_config(
  'request.jwt.claim.sub',
  '19100000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$ select public.block_current_partner() $$,
  'the first member can block the active partner'
);
select throws_ok(
  $$
    select public.create_couple_archive_reconnect_invite(
      '29100000-0000-0000-0000-000000000001'
    )
  $$,
  'P0001',
  'user_blocked',
  'an active block prevents reconnect invitation creation'
);
select is(
  (select count(*) from public.list_reconnectable_couple_archives()),
  0::bigint,
  'blocked archives are not offered as reconnectable'
);
select is(
  public.unblock_user('19100000-0000-0000-0000-000000000002'),
  true,
  'the blocker can reopen the possibility of reconnecting'
);

insert into captured_reconnect_invite (couple_id, invite_code)
select id, invite_code
from public.create_couple_archive_reconnect_invite(
  '29100000-0000-0000-0000-000000000001'
);

select is(
  (select count(*) from captured_reconnect_invite),
  1::bigint,
  'an explicit reconnect action creates one invitation'
);
select is(
  (
    select access_mode
    from public.get_current_couple_context()
  ),
  'pending',
  'the invitation owner enters a waiting state without reading shared data'
);
select is(
  private.is_readable_couple_member(
    '29100000-0000-0000-0000-000000000001',
    '19100000-0000-0000-0000-000000000001'
  ),
  false,
  'creating a reconnect invitation does not reveal the hidden archive'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '19100000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.get_current_couple_context()),
  0::bigint,
  'the former partner remains disconnected until accepting the code'
);
select lives_ok(
  format(
    'select public.join_couple_by_code(%L)',
    (select invite_code from captured_reconnect_invite)
  ),
  'the former partner can explicitly accept the reconnect invitation'
);
select is(
  (
    select access_mode
    from public.get_current_couple_context()
  ),
  'active',
  'the accepting partner regains the active couple context'
);

reset role;

select is(
  (
    select status
    from public.couples
    where id = '29100000-0000-0000-0000-000000000001'
  ),
  'active',
  'mutual reconnection restores the original couple'
);
select is(
  (
    select disconnect_reason
    from public.couples
    where id = '29100000-0000-0000-0000-000000000001'
  ),
  null::text,
  'successful reconnection clears the block separation marker'
);
select is(
  (
    select archive_expires_at
    from public.couples
    where id = '29100000-0000-0000-0000-000000000001'
  ),
  null::timestamptz,
  'successful reconnection cancels scheduled archive deletion'
);
select is(
  private.is_readable_couple_member(
    '29100000-0000-0000-0000-000000000001',
    '19100000-0000-0000-0000-000000000001'
  ),
  true,
  'shared data becomes readable only after mutual reconnection'
);

select set_config(
  'request.jwt.claim.sub',
  '19100000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select lives_ok(
  $$ select public.block_current_partner() $$,
  'the relationship can be blocked again after reconnection'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '19100000-0000-0000-0000-000000000002',
  true
);
set local role authenticated;

insert into captured_new_invite (couple_id, invite_code)
select id, invite_code
from public.create_couple_invite();

select isnt(
  (select couple_id from captured_new_invite),
  '29100000-0000-0000-0000-000000000001'::uuid,
  'a hidden blocked archive does not prevent creating a new relationship'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '19100000-0000-0000-0000-000000000001',
  true
);
set local role authenticated;

select throws_ok(
  format(
    'select public.join_couple_by_code(%L)',
    (select invite_code from captured_new_invite)
  ),
  'P0001',
  'user_blocked',
  'the same blocked pair cannot reconnect through a fresh invite'
);

reset role;

select set_config(
  'request.jwt.claim.sub',
  '19100000-0000-0000-0000-000000000003',
  true
);
set local role authenticated;

select lives_ok(
  format(
    'select public.join_couple_by_code(%L)',
    (select invite_code from captured_new_invite)
  ),
  'a different user can accept the fresh invitation'
);

reset role;

select is(
  (
    select status
    from public.couples
    where id = (select couple_id from captured_new_invite)
  ),
  'active',
  'the former partner can form a new active couple'
);
select is(
  (
    select user_b_id
    from public.couples
    where id = (select couple_id from captured_new_invite)
  ),
  '19100000-0000-0000-0000-000000000003'::uuid,
  'the new relationship contains the consenting new partner'
);
select is(
  (
    select status
    from public.couples
    where id = '29100000-0000-0000-0000-000000000001'
  ),
  'disconnected',
  'the old blocked archive remains isolated until deletion'
);
select is(
  (select count(*) from public.user_blocks),
  1::bigint,
  'forming a new relationship does not silently remove the safety block'
);

select * from finish();
rollback;
