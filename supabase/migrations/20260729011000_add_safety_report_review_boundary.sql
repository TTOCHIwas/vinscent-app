alter table public.safety_reports
  add column reviewed_by text;

update public.safety_reports
set
  moderation_note = null,
  reviewed_at = null,
  reviewed_by = null
where status = 'pending';

update public.safety_reports
set
  reviewed_at = coalesce(reviewed_at, updated_at, created_at),
  reviewed_by = 'legacy-moderation'
where status <> 'pending';

alter table public.safety_reports
  add constraint safety_reports_reviewed_by_check
    check (
      reviewed_by is null
      or char_length(reviewed_by) between 1 and 120
    ),
  add constraint safety_reports_review_state_check
    check (
      (
        status = 'pending'
        and moderation_note is null
        and reviewed_at is null
        and reviewed_by is null
      )
      or (
        status <> 'pending'
        and reviewed_at is not null
        and reviewed_by is not null
      )
    );

create table public.safety_report_reviews (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null
    references public.safety_reports(id) on delete cascade,
  decision_status text not null,
  reviewer_id text not null,
  moderation_note text,
  reviewed_at timestamptz not null default now(),

  constraint safety_report_reviews_decision_check
    check (decision_status in ('reviewed', 'actioned', 'dismissed')),
  constraint safety_report_reviews_reviewer_check
    check (char_length(reviewer_id) between 1 and 120),
  constraint safety_report_reviews_note_check
    check (
      moderation_note is null
      or char_length(moderation_note) <= 2000
    )
);

create index safety_report_reviews_report_idx
  on public.safety_report_reviews (report_id, reviewed_at desc, id);

alter table public.safety_report_reviews enable row level security;

revoke all on table public.safety_report_reviews
  from public, anon, authenticated, service_role;
grant select on table public.safety_report_reviews to service_role;

insert into public.safety_report_reviews (
  report_id,
  decision_status,
  reviewer_id,
  moderation_note,
  reviewed_at
)
select
  report.id,
  report.status,
  report.reviewed_by,
  report.moderation_note,
  report.reviewed_at
from public.safety_reports as report
where report.status <> 'pending';

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
    new.reviewed_by := null;
  end if;

  return new;
end;
$$;

revoke all on function private.requeue_changed_safety_report() from public;

create or replace function public.review_safety_report(
  requested_report_id uuid,
  requested_status text,
  requested_reviewer_id text,
  requested_note text default null
)
returns table (
  reviewed_report_id uuid,
  review_status text,
  reviewer_id text,
  review_time timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_status text := lower(btrim(requested_status));
  normalized_reviewer_id text := nullif(btrim(requested_reviewer_id), '');
  normalized_note text := nullif(btrim(requested_note), '');
  target_report public.safety_reports%rowtype;
begin
  if requested_report_id is null then
    perform private.raise_app_error('invalid_safety_report_id');
  end if;

  if normalized_status is null
    or normalized_status not in ('reviewed', 'actioned', 'dismissed')
  then
    perform private.raise_app_error('invalid_safety_report_decision');
  end if;

  if normalized_reviewer_id is null
    or char_length(normalized_reviewer_id) > 120
  then
    perform private.raise_app_error('invalid_safety_report_reviewer');
  end if;

  if normalized_note is not null and char_length(normalized_note) > 2000 then
    perform private.raise_app_error('safety_report_review_note_too_long');
  end if;

  select report.*
  into target_report
  from public.safety_reports as report
  where report.id = requested_report_id
  for update;

  if not found then
    perform private.raise_app_error('safety_report_not_found');
  end if;

  if target_report.status <> 'pending' then
    if target_report.status = normalized_status
      and target_report.reviewed_by = normalized_reviewer_id
      and target_report.moderation_note is not distinct from normalized_note
    then
      return query
      select
        target_report.id,
        target_report.status,
        target_report.reviewed_by,
        target_report.reviewed_at;
      return;
    end if;

    perform private.raise_app_error('safety_report_already_reviewed');
  end if;

  update public.safety_reports as report
  set
    status = normalized_status,
    moderation_note = normalized_note,
    reviewed_at = now(),
    reviewed_by = normalized_reviewer_id
  where report.id = target_report.id
  returning report.* into target_report;

  insert into public.safety_report_reviews (
    report_id,
    decision_status,
    reviewer_id,
    moderation_note,
    reviewed_at
  )
  values (
    target_report.id,
    target_report.status,
    target_report.reviewed_by,
    target_report.moderation_note,
    target_report.reviewed_at
  );

  return query
  select
    target_report.id,
    target_report.status,
    target_report.reviewed_by,
    target_report.reviewed_at;
end;
$$;

revoke all on table public.safety_reports from service_role;
grant select on table public.safety_reports to service_role;

revoke execute on function public.review_safety_report(
  uuid,
  text,
  text,
  text
) from public, anon, authenticated;
grant execute on function public.review_safety_report(
  uuid,
  text,
  text,
  text
) to service_role;
