begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(4);

insert into public.storage_cleanup_requests
  (bucket_id, object_path, cleanup_reason, created_at, status, processed_at, completion_outcome)
select 'couple-recordings', 'retention-test/' || label, 'orphan_recording',
  now() - interval '120 days', status, now() - age, outcome
from (values
  ('old',        'completed',  interval '90 days 1 second', 'deleted'),
  ('legacy',     'completed',  interval '100 days',         null),
  ('referenced', 'completed',  interval '100 days',         'still_referenced'),
  ('boundary',   'completed',  interval '90 days',          'deleted'),
  ('recent',     'completed',  interval '1 day',            'deleted'),
  ('undated',    'completed',  null,                        null),
  ('waiting',    'pending',    null,                        null),
  ('working',    'processing', null,                        null),
  ('failed',     'failed',     interval '100 days',         null)
) as fixture(label, status, age, outcome);

select private.purge_completed_storage_cleanup_requests();

select results_eq(
  $$select object_path from public.storage_cleanup_requests
    where object_path like 'retention-test/%' order by object_path$$,
  $$values ('retention-test/boundary'), ('retention-test/failed'),
    ('retention-test/recent'), ('retention-test/undated'),
    ('retention-test/waiting'), ('retention-test/working')$$,
  'expire only completed requests strictly older than 90 days by completion time'
);
select ok(not has_function_privilege('authenticated',
  'private.purge_completed_storage_cleanup_requests()', 'EXECUTE'),
  'clients cannot run history cleanup');
select ok((select command like '%private.purge_expired_operational_records()%'
  and command like '%private.purge_completed_storage_cleanup_requests()%'
  from cron.job where jobname = 'purge-expired-operational-records'),
  'the existing daily job schedules both cleanups');
select ok((select has_function_privilege(username,
  'private.purge_completed_storage_cleanup_requests()', 'EXECUTE')
  from cron.job where jobname = 'purge-expired-operational-records'),
  'the daily job owner can execute history cleanup');

select * from finish();
rollback;
