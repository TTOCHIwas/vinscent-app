create or replace function private.requeue_changed_safety_report()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status <> 'pending'
    and (
      new.reported_user_id is distinct from old.reported_user_id
      or new.couple_id is distinct from old.couple_id
      or new.reason is distinct from old.reason
      or new.details is distinct from old.details
      or new.content_snapshot is distinct from old.content_snapshot
    )
  then
    new.status := 'pending';
    new.moderation_note := null;
    new.reviewed_at := null;
  end if;

  return new;
end;
$$;

revoke all on function private.requeue_changed_safety_report() from public;

create trigger safety_reports_requeue_changed_report
  before update on public.safety_reports
  for each row
  execute function private.requeue_changed_safety_report();
