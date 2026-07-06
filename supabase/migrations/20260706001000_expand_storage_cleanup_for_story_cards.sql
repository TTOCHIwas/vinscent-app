alter table public.storage_cleanup_requests
  drop constraint if exists storage_cleanup_requests_bucket_id_check,
  drop constraint if exists storage_cleanup_requests_cleanup_reason_check;

alter table public.storage_cleanup_requests
  add constraint storage_cleanup_requests_bucket_id_check
    check (
      bucket_id in (
        'couple-recordings',
        'couple-characters',
        'story-cards'
      )
    ) not valid,
  add constraint storage_cleanup_requests_cleanup_reason_check
    check (
      cleanup_reason in (
        'orphan_recording',
        'archive_recording',
        'archive_character',
        'orphan_story_card',
        'archive_story_card'
      )
    ) not valid;

alter table public.storage_cleanup_requests
  validate constraint storage_cleanup_requests_bucket_id_check;

alter table public.storage_cleanup_requests
  validate constraint storage_cleanup_requests_cleanup_reason_check;
