create table public.story_card_read_receipts (
  card_id uuid not null references public.story_loop_cards(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (card_id, user_id)
);

create index story_card_read_receipts_user_id_idx
  on public.story_card_read_receipts(user_id);

alter table public.story_card_read_receipts enable row level security;

insert into public.story_card_read_receipts (
  card_id,
  user_id,
  seen_at
)
select
  card.id,
  member.user_id,
  now()
from public.story_loop_cards as card
join public.couples as couple
  on couple.id = card.couple_id
cross join lateral (
  values (couple.user_a_id), (couple.user_b_id)
) as member(user_id)
where member.user_id is not null
on conflict (card_id, user_id) do nothing;

drop function public.get_story_card_stack(date, uuid);

create function public.get_story_card_stack(
  target_date date,
  target_author_user_id uuid
)
returns table (
  "position" integer,
  card_id uuid,
  author_user_id uuid,
  preview_path text,
  scene_data_path text,
  has_photo boolean,
  has_drawing boolean,
  has_text boolean,
  submitted_at timestamptz,
  revision integer,
  is_featured boolean,
  can_delete boolean,
  can_feature boolean,
  is_read boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into current_couple_context
  from private.get_current_couple_context()
  limit 1;

  if not found
    or target_date is null
    or target_author_user_id is null
    or current_couple_context.relationship_start_date is null
    or target_date < current_couple_context.relationship_start_date
    or target_date > current_couple_context.current_couple_date
    or (
      target_author_user_id is distinct from current_couple_context.user_a_id
      and target_author_user_id is distinct from current_couple_context.user_b_id
    )
  then
    return;
  end if;

  return query
    with visible_cards as (
      select slc.*
      from public.story_loop_cards as slc
      where slc.couple_id = current_couple_context.id
        and slc.couple_date = target_date
        and slc.author_user_id = target_author_user_id
      order by
        case
          when target_date < current_couple_context.current_couple_date
            then slc.is_featured::integer
          else 0
        end desc,
        slc.submitted_at desc,
        slc.id desc
      limit case
        when target_date < current_couple_context.current_couple_date then 1
        else 2147483647
      end
    )
    select
      row_number() over (
        order by vc.submitted_at, vc.id
      )::integer,
      vc.id,
      vc.author_user_id,
      vc.preview_path,
      vc.scene_data_path,
      vc.has_photo,
      vc.has_drawing,
      vc.has_text,
      vc.submitted_at,
      vc.revision,
      vc.is_featured,
      current_couple_context.access_mode = 'active'
        and target_date = current_couple_context.current_couple_date
        and vc.author_user_id = current_user_id,
      current_couple_context.access_mode = 'active'
        and target_date = current_couple_context.current_couple_date
        and vc.author_user_id = current_user_id,
      vc.author_user_id = current_user_id
        or exists (
          select 1
          from public.story_card_read_receipts as receipt
          where receipt.card_id = vc.id
            and receipt.user_id = current_user_id
        )
    from visible_cards as vc
    order by vc.submitted_at, vc.id;
end;
$$;

create function public.acknowledge_story_card(target_card_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  current_couple_context record;
  readable_card public.story_loop_cards%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;
  if target_card_id is null then
    perform private.raise_app_error('invalid_story_card_id');
  end if;

  select *
  into current_couple_context
  from private.get_current_couple_context()
  limit 1;

  if not found then
    return false;
  end if;

  select card.*
  into readable_card
  from public.story_loop_cards as card
  where card.id = target_card_id
    and card.couple_id = current_couple_context.id
    and current_couple_context.relationship_start_date is not null
    and card.couple_date >= current_couple_context.relationship_start_date
    and card.couple_date <= current_couple_context.current_couple_date
    and (
      card.couple_date = current_couple_context.current_couple_date
      or card.is_featured
    )
  limit 1;

  if not found then
    return false;
  end if;
  if readable_card.author_user_id = current_user_id then
    return true;
  end if;

  insert into public.story_card_read_receipts (
    card_id,
    user_id,
    seen_at
  )
  values (
    readable_card.id,
    current_user_id,
    now()
  )
  on conflict (card_id, user_id)
  do update
  set seen_at = excluded.seen_at;

  return true;
end;
$$;

revoke all on table public.story_card_read_receipts
  from public, anon, authenticated;

revoke execute on function public.get_story_card_stack(date, uuid)
  from public, anon;
revoke execute on function public.acknowledge_story_card(uuid)
  from public, anon;

grant execute on function public.get_story_card_stack(date, uuid)
  to authenticated;
grant execute on function public.acknowledge_story_card(uuid)
  to authenticated;
