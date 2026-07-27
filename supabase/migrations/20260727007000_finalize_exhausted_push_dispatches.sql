create or replace function public.finalize_exhausted_push_notification_dispatches(
  requested_limit integer default 100
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  finalized_count integer;
begin
  if requested_limit is null
    or requested_limit < 1
    or requested_limit > 200
  then
    raise exception 'invalid_exhausted_dispatch_limit';
  end if;

  with exhausted_dispatches as (
    update public.push_notification_dispatches as dispatch
    set
      status = 'failed',
      completed_at = now(),
      available_at = now(),
      error_message = coalesce(
        dispatch.error_message,
        'dispatch_abandoned_after_final_attempt'
      )
    where (
      dispatch.notification_type,
      dispatch.source_id,
      dispatch.receiver_user_id
    ) in (
      select
        candidate.notification_type,
        candidate.source_id,
        candidate.receiver_user_id
      from public.push_notification_dispatches as candidate
      where candidate.status = 'processing'
        and candidate.attempt_count >= candidate.max_attempts
        and candidate.claimed_at < now() - interval '5 minutes'
      order by candidate.claimed_at, candidate.created_at
      for update skip locked
      limit requested_limit
    )
    returning
      dispatch.notification_type,
      dispatch.source_id,
      dispatch.receiver_user_id,
      dispatch.error_message
  ),
  recorded_deliveries as (
    insert into public.push_notification_deliveries (
      notification_type,
      source_id,
      receiver_user_id,
      target_token_count,
      success_count,
      failure_count,
      status,
      error_message
    )
    select
      exhausted.notification_type,
      exhausted.source_id,
      exhausted.receiver_user_id,
      0,
      0,
      0,
      'failed',
      exhausted.error_message
    from exhausted_dispatches as exhausted
    returning 1
  )
  select count(*)::integer
  into finalized_count
  from recorded_deliveries;

  return finalized_count;
end;
$$;

revoke execute on function public.finalize_exhausted_push_notification_dispatches(
  integer
) from public, anon, authenticated;

grant execute on function public.finalize_exhausted_push_notification_dispatches(
  integer
) to service_role;
