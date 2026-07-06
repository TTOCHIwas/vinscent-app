insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'story-cards',
  'story-cards',
  false,
  5242880,
  array[
    'image/png',
    'image/jpeg',
    'image/webp',
    'application/json'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table public.daily_story_loops (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  couple_date date not null,
  status text not null,
  question_generated_at timestamptz,
  story_edit_locked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint daily_story_loops_couple_date_unique
    unique (couple_id, couple_date),
  constraint daily_story_loops_reference_unique
    unique (couple_id, couple_date, id),
  constraint daily_story_loops_status_check
    check (
      status in (
        'waiting_partner_card',
        'question_generated',
        'answered_by_one',
        'completed'
      )
    )
);

create table public.story_loop_cards (
  id uuid primary key default gen_random_uuid(),
  story_loop_id uuid not null references public.daily_story_loops(id) on delete cascade,
  couple_id uuid not null references public.couples(id) on delete cascade,
  couple_date date not null,
  author_user_id uuid not null references auth.users(id) on delete cascade,
  preview_path text not null,
  scene_data_path text not null,
  has_photo boolean not null default false,
  has_drawing boolean not null default false,
  has_text boolean not null default false,
  submitted_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  revision integer not null default 1,

  constraint story_loop_cards_loop_author_unique
    unique (story_loop_id, author_user_id),
  constraint story_loop_cards_revision_check
    check (revision >= 1),
  constraint story_loop_cards_content_required
    check (has_photo or has_drawing or has_text),
  constraint story_loop_cards_preview_path_check
    check (
      preview_path = couple_id::text
        || '/loops/'
        || couple_date::text
        || '/'
        || author_user_id::text
        || '/preview.png'
    ),
  constraint story_loop_cards_scene_data_path_check
    check (
      scene_data_path = couple_id::text
        || '/loops/'
        || couple_date::text
        || '/'
        || author_user_id::text
        || '/scene.json'
    )
);

create table public.story_loop_notification_events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  story_loop_id uuid not null references public.daily_story_loops(id) on delete cascade,
  card_id uuid references public.story_loop_cards(id) on delete set null,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  receiver_user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null,
  created_at timestamptz not null default now(),

  constraint story_loop_notification_events_type_check
    check (
      event_type in (
        'partner_story_card_uploaded',
        'question_generated'
      )
    )
);

create index daily_story_loops_couple_date_idx
  on public.daily_story_loops (couple_id, couple_date desc);

create index story_loop_cards_couple_date_idx
  on public.story_loop_cards (couple_id, couple_date desc, submitted_at asc);

create index story_loop_cards_loop_submitted_idx
  on public.story_loop_cards (story_loop_id, submitted_at asc);

create index story_loop_notification_events_receiver_created_idx
  on public.story_loop_notification_events (receiver_user_id, created_at desc);

alter table public.daily_story_loops enable row level security;
alter table public.story_loop_cards enable row level security;
alter table public.story_loop_notification_events enable row level security;

create trigger daily_story_loops_set_updated_at
  before update on public.daily_story_loops
  for each row
  execute function public.set_updated_at();

create trigger story_loop_cards_set_updated_at
  before update on public.story_loop_cards
  for each row
  execute function public.set_updated_at();

create or replace function private.is_current_user_readable_story_card_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select object_bucket_id = 'story-cards'
    and cardinality(regexp_split_to_array(object_name, '/')) = 5
    and exists (
      select 1
      from public.couples as c
      where private.is_readable_couple_member(c.id, (select auth.uid()))
        and split_part(object_name, '/', 1) = c.id::text
        and split_part(object_name, '/', 2) = 'loops'
        and split_part(object_name, '/', 3) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        and (
          split_part(object_name, '/', 4) = c.user_a_id::text
          or (
            c.user_b_id is not null
            and split_part(object_name, '/', 4) = c.user_b_id::text
          )
        )
        and split_part(object_name, '/', 5) in ('preview.png', 'scene.json')
    );
$$;

create or replace function private.is_current_user_writable_story_card_storage_object(
  object_bucket_id text,
  object_name text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  select object_bucket_id = 'story-cards'
    and cardinality(regexp_split_to_array(object_name, '/')) = 5
    and exists (
      select 1
      from public.couples as c
      where c.status = 'active'
        and (
          c.user_a_id = (select auth.uid())
          or c.user_b_id = (select auth.uid())
        )
        and split_part(object_name, '/', 1) = c.id::text
        and split_part(object_name, '/', 2) = 'loops'
        and split_part(object_name, '/', 3) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        and split_part(object_name, '/', 4) = (select auth.uid())::text
        and split_part(object_name, '/', 5) in ('preview.png', 'scene.json')
    );
$$;

create policy "daily_story_loops_select_member"
  on public.daily_story_loops
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "story_loop_cards_select_member"
  on public.story_loop_cards
  for select
  to authenticated
  using (
    private.is_readable_couple_member(couple_id, (select auth.uid()))
  );

create policy "story_cards_storage_select_member"
  on storage.objects
  for select
  to authenticated
  using (
    private.is_current_user_readable_story_card_storage_object(bucket_id, name)
  );

create policy "story_cards_storage_insert_member"
  on storage.objects
  for insert
  to authenticated
  with check (
    private.is_current_user_writable_story_card_storage_object(bucket_id, name)
  );

create policy "story_cards_storage_update_member"
  on storage.objects
  for update
  to authenticated
  using (
    private.is_current_user_writable_story_card_storage_object(bucket_id, name)
  )
  with check (
    private.is_current_user_writable_story_card_storage_object(bucket_id, name)
  );

revoke execute on function private.is_current_user_readable_story_card_storage_object(text, text)
  from public, anon, authenticated;
revoke execute on function private.is_current_user_writable_story_card_storage_object(text, text)
  from public, anon, authenticated;
