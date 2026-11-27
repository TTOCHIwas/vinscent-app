create function private.purge_completed_storage_cleanup_requests()
returns integer
language sql
security definer
set search_path = ''
as $$
  with expired as (
    select id
    from public.storage_cleanup_requests
    where status = 'completed'
      and processed_at < now() - interval '90 days'
    order by processed_at, id
    limit 5000
    for update skip locked
  ), removed as (
    delete from public.storage_cleanup_requests as request
    using expired
    where request.id = expired.id
    returning request.id
  )
  select count(*)::integer from removed;
$$;

revoke all on function private.purge_completed_storage_cleanup_requests()
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
  execute format('grant execute on function private.purge_completed_storage_cleanup_requests() to %I',
    daily_job.username);
  perform cron.alter_job(daily_job.jobid,
    command := rtrim(btrim(daily_job.command), ';' || chr(10) || chr(13) || ' ')
      || ';' || chr(10) || 'select private.purge_completed_storage_cleanup_requests();');
end;
$$;
