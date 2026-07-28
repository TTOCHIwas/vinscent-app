begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

create temporary table observed_couple_deletion_signals (
  couple_id uuid not null
);

create or replace function pg_temp.capture_couple_deletion_signal()
returns trigger
language plpgsql
as $$
begin
  insert into observed_couple_deletion_signals (couple_id)
  values (new.id);
  return new;
end;
$$;

create trigger capture_couple_deletion_signal
  after update of updated_at on public.couples
  for each row
  when (old.updated_at is distinct from new.updated_at)
  execute function pg_temp.capture_couple_deletion_signal();

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '10000000-0000-0000-0000-000000000021',
    'authenticated',
    'authenticated',
    'delete-target@example.test',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000022',
    'authenticated',
    'authenticated',
    'active-partner@example.test',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000023',
    'authenticated',
    'authenticated',
    'archived-partner@example.test',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000024',
    'authenticated',
    'authenticated',
    'unrelated-a@example.test',
    now(),
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000025',
    'authenticated',
    'authenticated',
    'unrelated-b@example.test',
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
  disconnected_at,
  disconnected_by_user_id,
  archive_expires_at
)
values
  (
    '20000000-0000-0000-0000-000000000021',
    'DEL021',
    '10000000-0000-0000-0000-000000000021',
    '10000000-0000-0000-0000-000000000022',
    current_date - 30,
    'active',
    now() - interval '30 days',
    null,
    null,
    null
  ),
  (
    '20000000-0000-0000-0000-000000000022',
    'DEL022',
    '10000000-0000-0000-0000-000000000023',
    '10000000-0000-0000-0000-000000000021',
    current_date - 60,
    'disconnected',
    now() - interval '60 days',
    now() - interval '1 day',
    '10000000-0000-0000-0000-000000000023',
    now() + interval '29 days'
  ),
  (
    '20000000-0000-0000-0000-000000000023',
    'KEEP23',
    '10000000-0000-0000-0000-000000000024',
    '10000000-0000-0000-0000-000000000025',
    current_date - 10,
    'active',
    now() - interval '10 days',
    null,
    null,
    null
  );

select ok(
  not has_function_privilege(
    'authenticated',
    'public.delete_account_shared_data(uuid)',
    'EXECUTE'
  ),
  'authenticated clients cannot call the account deletion boundary directly'
);

set local role service_role;

select is(
  public.delete_account_shared_data(
    '10000000-0000-0000-0000-000000000021'
  ),
  2,
  'all couples containing the target user are deleted'
);

reset role;

select is(
  (
    select count(*)
    from observed_couple_deletion_signals
    where couple_id in (
      '20000000-0000-0000-0000-000000000021',
      '20000000-0000-0000-0000-000000000022'
    )
  ),
  2::bigint,
  'each deleted couple emits an update signal for filtered realtime clients'
);

select is(
  (
    select count(*)
    from public.couples
    where user_a_id = '10000000-0000-0000-0000-000000000021'
      or user_b_id = '10000000-0000-0000-0000-000000000021'
  ),
  0::bigint,
  'the target user has no remaining couple data'
);

select is(
  (
    select count(*)
    from public.couples
    where id = '20000000-0000-0000-0000-000000000023'
  ),
  1::bigint,
  'an unrelated couple remains untouched'
);

select is(
  (
    select count(*)
    from auth.users
    where id in (
      '10000000-0000-0000-0000-000000000022',
      '10000000-0000-0000-0000-000000000023'
    )
  ),
  2::bigint,
  'both partner authentication accounts remain'
);

select is(
  (
    select count(*)
    from auth.users
    where id = '10000000-0000-0000-0000-000000000021'
  ),
  1::bigint,
  'the RPC leaves target authentication deletion to the server handler'
);

set local role service_role;

select is(
  public.delete_account_shared_data(
    '10000000-0000-0000-0000-000000000021'
  ),
  0,
  'repeating shared data deletion is idempotent'
);

reset role;

select * from finish();
rollback;
