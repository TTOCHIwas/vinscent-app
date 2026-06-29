create table public.storage_cleanup_requests (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  object_path text not null,
  cleanup_reason text not null,
  source_couple_id uuid references public.couples(id) on delete set null,
  status text not null default 'pending',
  last_error text,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint storage_cleanup_requests_bucket_id_check
    check (bucket_id in ('couple-recordings', 'couple-characters')),
  constraint storage_cleanup_requests_object_path_check
    check (char_length(btrim(object_path)) between 1 and 2048),
  constraint storage_cleanup_requests_cleanup_reason_check
    check (
      cleanup_reason in (
        'orphan_recording',
        'archive_recording',
        'archive_character'
      )
    ),
  constraint storage_cleanup_requests_status_check
    check (status in ('pending', 'processing', 'completed', 'failed'))
);

create index storage_cleanup_requests_status_created_idx
  on public.storage_cleanup_requests (status, created_at);

create unique index storage_cleanup_requests_pending_unique
  on public.storage_cleanup_requests (bucket_id, object_path)
  where status in ('pending', 'processing');

alter table public.storage_cleanup_requests enable row level security;

create trigger storage_cleanup_requests_set_updated_at
  before update on public.storage_cleanup_requests
  for each row
  execute function public.set_updated_at();

create or replace function private.enqueue_storage_cleanup_request(
  requested_bucket_id text,
  requested_object_path text,
  requested_cleanup_reason text,
  requested_source_couple_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_bucket_id text := btrim(requested_bucket_id);
  normalized_object_path text := btrim(requested_object_path);
  normalized_cleanup_reason text := btrim(requested_cleanup_reason);
begin
  if normalized_bucket_id is null or normalized_bucket_id = '' then
    return;
  end if;

  if normalized_object_path is null or normalized_object_path = '' then
    return;
  end if;

  if normalized_cleanup_reason is null or normalized_cleanup_reason = '' then
    return;
  end if;

  insert into public.storage_cleanup_requests (
    bucket_id,
    object_path,
    cleanup_reason,
    source_couple_id
  )
  values (
    normalized_bucket_id,
    normalized_object_path,
    normalized_cleanup_reason,
    requested_source_couple_id
  )
  on conflict do nothing;
end;
$$;

revoke execute on function private.enqueue_storage_cleanup_request(text, text, text, uuid)
  from public, anon, authenticated;
