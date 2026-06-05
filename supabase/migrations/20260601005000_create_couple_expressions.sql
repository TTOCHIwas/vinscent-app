create table public.couple_expressions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  receiver_user_id uuid not null references auth.users(id) on delete cascade,
  expression_type text not null,
  sent_at timestamptz not null default now(),

  constraint couple_expressions_type_check
    check (
      expression_type in (
        'miss_you',
        'thanks',
        'feeling_down',
        'cheer_up'
      )
    ),
  constraint couple_expressions_distinct_users
    check (sender_user_id <> receiver_user_id)
);

create index couple_expressions_couple_sent_at_idx
  on public.couple_expressions (couple_id, sent_at desc);

create index couple_expressions_receiver_sent_at_idx
  on public.couple_expressions (receiver_user_id, sent_at desc);

alter table public.couple_expressions enable row level security;

create policy "couple_expressions_select_member"
  on public.couple_expressions
  for select
  to authenticated
  using (
    private.is_active_couple_member(couple_id, (select auth.uid()))
  );

create or replace function public.send_couple_expression(
  requested_expression_type text
)
returns table (
  id uuid,
  couple_id uuid,
  sender_user_id uuid,
  receiver_user_id uuid,
  expression_type text,
  sent_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
  normalized_expression_type text := btrim($1);
  target_receiver_user_id uuid;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  active_couple := private.get_active_couple_for_current_user();

  if normalized_expression_type not in (
    'miss_you',
    'thanks',
    'feeling_down',
    'cheer_up'
  ) then
    perform private.raise_app_error('invalid_expression_type');
  end if;

  target_receiver_user_id := case
    when active_couple.user_a_id = current_user_id then active_couple.user_b_id
    when active_couple.user_b_id = current_user_id then active_couple.user_a_id
    else null
  end;

  if target_receiver_user_id is null then
    perform private.raise_app_error('active_couple_required');
  end if;

  return query
    insert into public.couple_expressions (
      couple_id,
      sender_user_id,
      receiver_user_id,
      expression_type
    )
    values (
      active_couple.id,
      current_user_id,
      target_receiver_user_id,
      normalized_expression_type
    )
    returning
      public.couple_expressions.id,
      public.couple_expressions.couple_id,
      public.couple_expressions.sender_user_id,
      public.couple_expressions.receiver_user_id,
      public.couple_expressions.expression_type,
      public.couple_expressions.sent_at;
end;
$$;

create or replace function public.get_couple_expression_summary_for_date(
  target_date date
)
returns table (
  expression_type text,
  sent_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
begin
  active_couple := private.get_active_couple_for_current_user();

  if active_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_date is null
    or target_date < active_couple.relationship_start_date
    or target_date > private.current_app_date()
  then
    return query
      select expression_types.expression_type, 0::integer
      from (
        values
          ('miss_you'::text, 1),
          ('thanks'::text, 2),
          ('feeling_down'::text, 3),
          ('cheer_up'::text, 4)
      ) as expression_types(expression_type, sort_order)
      order by sort_order;

    return;
  end if;

  return query
    with expression_types(expression_type, sort_order) as (
      values
        ('miss_you'::text, 1),
        ('thanks'::text, 2),
        ('feeling_down'::text, 3),
        ('cheer_up'::text, 4)
    ),
    expression_counts as (
      select
        ce.expression_type,
        count(*)::integer as sent_count
      from public.couple_expressions as ce
      where ce.couple_id = active_couple.id
        and (ce.sent_at at time zone active_couple.timezone)::date = target_date
      group by ce.expression_type
    )
    select
      expression_types.expression_type,
      coalesce(expression_counts.sent_count, 0)
    from expression_types
    left join expression_counts
      on expression_counts.expression_type = expression_types.expression_type
    order by expression_types.sort_order;
end;
$$;

revoke execute on function public.send_couple_expression(text)
  from public, anon;
revoke execute on function public.get_couple_expression_summary_for_date(date)
  from public, anon;

grant execute on function public.send_couple_expression(text)
  to authenticated;
grant execute on function public.get_couple_expression_summary_for_date(date)
  to authenticated;
