create function private.purge_expired_media_notification_events()
returns table (recording_removed bigint, card_removed bigint)
language sql
security definer
set search_path = ''
as $$
  with queued as materialized (
    select distinct split_part(url, '?', 1) as endpoint
    from net.http_request_queue
  ), open_dispatches as materialized (
    select notification_type, source_id, receiver_user_id
    from public.push_notification_dispatches
    where notification_type in ('recording_activity', 'partner_story_card_uploaded')
      and (status = 'processing' or (status = 'failed' and attempt_count < max_attempts))
  ), recordings as (
    select e.id
    from public.recording_notification_events e
    where e.created_at < now() - interval '90 days'
      and not exists (select 1 from queued where endpoint like '%/send-recording-notification')
      and not exists (
        select 1 from open_dispatches d where d.notification_type = 'recording_activity'
          and d.source_id = e.id and d.receiver_user_id = e.receiver_user_id
      )
    order by e.created_at, e.id
    limit 5000 for update of e skip locked
  ), cards as (
    select e.id
    from public.story_loop_notification_events e
    where e.event_type = 'partner_story_card_uploaded'
      and e.created_at < now() - interval '90 days'
      and not exists (select 1 from queued where endpoint like '%/send-story-loop-notification')
      and not exists (
        select 1 from open_dispatches d where d.notification_type = e.event_type
          and d.source_id = e.id and d.receiver_user_id = e.receiver_user_id
      )
    order by e.created_at, e.id
    limit 5000 for update of e skip locked
  ), removed_recordings as (
    delete from public.recording_notification_events e using recordings
    where e.id = recordings.id returning e.id
  ), removed_cards as (
    delete from public.story_loop_notification_events e using cards
    where e.id = cards.id returning e.id
  )
  select (select count(*) from removed_recordings), (select count(*) from removed_cards);
$$;

revoke all on function private.purge_expired_media_notification_events()
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
  execute format('grant execute on function private.purge_expired_media_notification_events() to %I',
    daily_job.username);
  perform cron.alter_job(daily_job.jobid,
    command := rtrim(btrim(daily_job.command), ';' || chr(10) || chr(13) || ' ')
      || ';' || chr(10) || 'select * from private.purge_expired_media_notification_events();');
end;
$$;
