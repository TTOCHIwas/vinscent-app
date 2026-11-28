begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

insert into cron.job_run_details (jobid, runid, username, status, start_time, end_time)
select -1, -n, 'postgres', 'succeeded', date '1900-01-01', date '1900-01-02'
from generate_series(1, 5001) n;

insert into cron.job_run_details (jobid, runid, username, status, start_time, end_time)
select -2, id, 'supabase_admin', state, now() - interval '60 days', now() - age
from (values
  (-6001, 'succeeded', interval '7 days 1 second'),
  (-6002, 'succeeded', interval '7 days'),
  (-6003, 'failed', interval '30 days 1 second'),
  (-6004, 'failed', interval '30 days'),
  (-6005, 'succeeded', null),
  (-6006, 'running', interval '40 days'),
  (-6007, 'succeeded', interval '1 minute'),
  (-6008, 'failed', interval '8 days'),
  (-6009, 'failed', null)
) f(id, state, age);

select format('set local role %I', username)
from cron.job where jobname = 'purge-expired-operational-records'
\gexec
create temp table first_batch as select * from private.purge_expired_cron_runs();
reset role;
select is((select succeeded_removed from first_batch), 5000::bigint, 'cap each run at 5000 expired rows');
select is((select failed_removed from first_batch), 0::bigint, 'report failures separately');
select is((select count(*) from cron.job_run_details where jobid = -1), 1::bigint, 'leave overflow for a later run');

-- Drain any older history that was already present in the test database.
do $$
begin
  while exists (select 1 from private.purge_expired_cron_runs()
                where succeeded_removed + failed_removed > 0) loop
    null;
  end loop;
end;
$$;
select is((select count(*) from cron.job_run_details where jobid = -1), 0::bigint, 'collect overflow on later runs');
select results_eq(
  'select runid from cron.job_run_details where jobid = -2 order by runid desc',
  'values (-6002::bigint), (-6004), (-6005), (-6006), (-6007), (-6008), (-6009)',
  'retain exact boundaries, recent completions, unfinished and nonterminal runs');
select results_eq('select * from private.purge_expired_cron_runs()', 'values (0::bigint, 0::bigint)', 'repeat safely');
select ok((select command like '%private.purge_expired_operational_records()%private.purge_completed_storage_cleanup_requests()%private.purge_expired_media_notification_events()%private.purge_expired_cron_runs()%'
  and schedule = '17 18 * * *' from cron.job where jobname = 'purge-expired-operational-records'), 'keep existing daily steps and schedule');
select ok(not exists (select 1 from (values ('anon'), ('authenticated'), ('service_role')) r(role_name)
  where has_function_privilege(role_name, 'private.purge_expired_cron_runs()', 'execute')), 'deny application roles');
select * from finish();
rollback;
