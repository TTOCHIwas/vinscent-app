create function private.purge_expired_cron_runs()
returns table (succeeded_removed bigint, failed_removed bigint)
language sql
security definer
set search_path = ''
as $$
  with expired as (
    select runid
    from cron.job_run_details
    where end_time is not null
      and (
        (status = 'succeeded' and end_time < now() - interval '7 days')
        or (status = 'failed' and end_time < now() - interval '30 days')
      )
    order by end_time, runid
    limit 5000
    for update skip locked
  ), removed as (
    delete from cron.job_run_details as run
    using expired
    where run.runid = expired.runid
    returning run.status
  )
  select count(*) filter (where status = 'succeeded'),
         count(*) filter (where status = 'failed')
  from removed;
$$;

revoke all on function private.purge_expired_cron_runs()
  from public, anon, authenticated, service_role;

do $$
declare
  daily_job cron.job%rowtype;
begin
  select * into strict daily_job from cron.job
  where jobname = 'purge-expired-operational-records';

  if daily_job.username not in ('postgres', 'supabase_admin') then
    raise exception 'unexpected operational retention job owner';
  end if;
  execute format('grant execute on function private.purge_expired_cron_runs() to %I',
    daily_job.username);
  perform cron.alter_job(daily_job.jobid,
    command := rtrim(btrim(daily_job.command), ';' || chr(10) || chr(13) || ' ')
      || ';' || chr(10) || 'select * from private.purge_expired_cron_runs();');
end;
$$;
