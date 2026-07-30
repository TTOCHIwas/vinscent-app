begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(27);

insert into auth.users (id, aud, role, email, created_at, updated_at)
values
  (
    '71000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'storage-cleanup-a@example.test',
    now(),
    now()
  ),
  (
    '71000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'storage-cleanup-b@example.test',
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
  connected_at
)
values (
  '72000000-0000-0000-0000-000000000001',
  'STORCLNP',
  '71000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000002',
  current_date - 30,
  'active',
  now()
);

insert into public.couple_recordings (
  id,
  couple_id,
  sender_user_id,
  storage_path,
  duration_ms
)
values (
  '73000000-0000-0000-0000-000000000001',
  '72000000-0000-0000-0000-000000000001',
  '71000000-0000-0000-0000-000000000001',
  '72000000-0000-0000-0000-000000000001/recordings/73000000-0000-0000-0000-000000000001.m4a',
  1000
);

insert into storage.objects (bucket_id, name)
values
  (
    'couple-recordings',
    '72000000-0000-0000-0000-000000000001/recordings/73000000-0000-0000-0000-000000000001.m4a'
  ),
  (
    'story-cards',
    '72000000-0000-0000-0000-000000000001/loops/old/orphan.png'
  ),
  (
    'story-cards',
    '72000000-0000-0000-0000-000000000001/loops/recent/orphan.png'
  );

update storage.objects
set created_at = now() - interval '2 hours'
where name in (
  '72000000-0000-0000-0000-000000000001/recordings/73000000-0000-0000-0000-000000000001.m4a',
  '72000000-0000-0000-0000-000000000001/loops/old/orphan.png'
);

select has_column(
  'public',
  'storage_cleanup_requests',
  'attempt_count',
  'cleanup requests track retry attempts'
);
select has_column(
  'public',
  'storage_cleanup_requests',
  'available_at',
  'cleanup requests schedule retry availability'
);
select has_column(
  'public',
  'storage_cleanup_requests',
  'claim_token',
  'cleanup claims have ownership tokens'
);
select has_column(
  'public',
  'storage_cleanup_requests',
  'completion_outcome',
  'completed cleanup requests retain a safe outcome'
);
select has_function(
  'public',
  'claim_storage_cleanup_requests',
  array['text', 'integer', 'uuid'],
  'storage workers claim cleanup requests through one boundary'
);
select has_function(
  'public',
  'complete_storage_cleanup_request',
  array['uuid', 'uuid', 'boolean', 'text', 'text', 'integer'],
  'storage workers complete cleanup requests through one boundary'
);
select has_function(
  'public',
  'is_storage_cleanup_object_referenced',
  array['text', 'text'],
  'storage workers revalidate references before deletion'
);
select has_function(
  'public',
  'reconcile_storage_cleanup_requests',
  array['integer', 'integer'],
  'storage workers can recover missing orphan requests'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.claim_storage_cleanup_requests(text,integer,uuid)',
    'EXECUTE'
  ),
  'clients cannot claim cleanup requests'
);
select ok(
  has_function_privilege(
    'service_role',
    'public.claim_storage_cleanup_requests(text,integer,uuid)',
    'EXECUTE'
  ),
  'the service worker can claim cleanup requests'
);

set local role service_role;

select ok(
  public.is_storage_cleanup_object_referenced(
    'couple-recordings',
    '72000000-0000-0000-0000-000000000001/recordings/73000000-0000-0000-0000-000000000001.m4a'
  ),
  'a current recording is protected from cleanup'
);
select ok(
  not public.is_storage_cleanup_object_referenced(
    'story-cards',
    '72000000-0000-0000-0000-000000000001/loops/old/orphan.png'
  ),
  'an orphan story artifact is eligible for cleanup'
);
select is(
  public.reconcile_storage_cleanup_requests(20, 60),
  1,
  'reconciliation enqueues only old unreferenced objects'
);

reset role;

select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where object_path =
      '72000000-0000-0000-0000-000000000001/loops/old/orphan.png'
      and status = 'pending'
  ),
  1::bigint,
  'the old orphan receives one pending cleanup request'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where object_path =
      '72000000-0000-0000-0000-000000000001/loops/recent/orphan.png'
  ),
  0::bigint,
  'recent uploads remain outside reconciliation'
);
select is(
  (
    select count(*)
    from public.storage_cleanup_requests
    where object_path =
      '72000000-0000-0000-0000-000000000001/recordings/73000000-0000-0000-0000-000000000001.m4a'
  ),
  0::bigint,
  'referenced objects never enter the cleanup queue'
);

create temporary table storage_cleanup_test_claims (
  claim_number integer primary key,
  request_id uuid not null,
  claim_token uuid not null
);
grant select, insert on table storage_cleanup_test_claims to service_role;

set local role service_role;

insert into storage_cleanup_test_claims (
  claim_number,
  request_id,
  claim_token
)
select 1, claimed.request_id, claimed.claim_token
from public.claim_storage_cleanup_requests(
  'storage-test-worker',
  10,
  null
) as claimed;

reset role;

select is(
  (select count(*) from storage_cleanup_test_claims),
  1::bigint,
  'one worker claims the reconciled request'
);
select is(
  (
    select status
    from public.storage_cleanup_requests
    where id = (
      select request_id
      from storage_cleanup_test_claims
      where claim_number = 1
    )
  ),
  'processing',
  'claiming moves cleanup work into processing'
);
select is(
  (
    select attempt_count
    from public.storage_cleanup_requests
    where id = (
      select request_id
      from storage_cleanup_test_claims
      where claim_number = 1
    )
  ),
  1,
  'claiming records the first attempt'
);

set local role service_role;

select is(
  public.complete_storage_cleanup_request(
    (select request_id from storage_cleanup_test_claims where claim_number = 1),
    (select claim_token from storage_cleanup_test_claims where claim_number = 1),
    false,
    null,
    'storage_object_delete_failed',
    0
  ),
  'pending',
  'a temporary deletion failure returns work to pending'
);

insert into storage_cleanup_test_claims (
  claim_number,
  request_id,
  claim_token
)
select 2, claimed.request_id, claimed.claim_token
from public.claim_storage_cleanup_requests(
  'storage-test-worker',
  10,
  null
) as claimed;

reset role;

select is(
  (
    select attempt_count
    from public.storage_cleanup_requests
    where id = (
      select request_id
      from storage_cleanup_test_claims
      where claim_number = 2
    )
  ),
  2,
  'a due retry increments the attempt count'
);
select isnt(
  (
    select claim_token
    from storage_cleanup_test_claims
    where claim_number = 1
  ),
  (
    select claim_token
    from storage_cleanup_test_claims
    where claim_number = 2
  ),
  'each claim receives a new ownership token'
);

set local role service_role;

select is(
  public.complete_storage_cleanup_request(
    (select request_id from storage_cleanup_test_claims where claim_number = 2),
    (select claim_token from storage_cleanup_test_claims where claim_number = 2),
    true,
    'deleted',
    null,
    0
  ),
  'completed',
  'a successful deletion completes cleanup work'
);

reset role;

select is(
  (
    select completion_outcome
    from public.storage_cleanup_requests
    where id = (
      select request_id
      from storage_cleanup_test_claims
      where claim_number = 2
    )
  ),
  'deleted',
  'the completed request records that Storage was deleted'
);
select is(
  (
    select status
    from public.storage_cleanup_requests
    where id = (
      select request_id
      from storage_cleanup_test_claims
      where claim_number = 2
    )
  ),
  'completed',
  'the cleanup request remains terminal after completion'
);

insert into public.storage_cleanup_requests (
  bucket_id,
  object_path,
  cleanup_reason,
  status,
  last_error,
  processed_at
)
values (
  'story-cards',
  '72000000-0000-0000-0000-000000000001/loops/legacy/failed.png',
  'orphan_story_card',
  'failed',
  'legacy one-shot failure',
  now()
);

set local role service_role;

insert into storage_cleanup_test_claims (
  claim_number,
  request_id,
  claim_token
)
select 3, claimed.request_id, claimed.claim_token
from public.claim_storage_cleanup_requests(
  'storage-test-worker',
  1,
  (
    select id
    from public.storage_cleanup_requests
    where object_path =
      '72000000-0000-0000-0000-000000000001/loops/legacy/failed.png'
  )
) as claimed;

reset role;

select is(
  (
    select count(*)
    from storage_cleanup_test_claims
    where claim_number = 3
  ),
  1::bigint,
  'the batch worker recovers a legacy one-shot failure'
);
select is(
  (
    select attempt_count
    from public.storage_cleanup_requests
    where object_path =
      '72000000-0000-0000-0000-000000000001/loops/legacy/failed.png'
  ),
  1,
  'a recovered legacy failure starts the bounded retry lifecycle'
);

select * from finish();
rollback;
