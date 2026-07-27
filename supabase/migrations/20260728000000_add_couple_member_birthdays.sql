create or replace function public.get_active_couple_member_birthdays()
returns table (
  member_role text,
  birth_date date
)
language sql
stable
security definer
set search_path = ''
as $$
  with active_couple as (
    select
      c.user_a_id,
      c.user_b_id
    from public.couples as c
    where c.status = 'active'
      and (
        c.user_a_id = (select auth.uid())
        or c.user_b_id = (select auth.uid())
      )
    limit 1
  )
  select
    case
      when p.id = (select auth.uid()) then 'self'::text
      else 'partner'::text
    end as member_role,
    p.birth_date
  from active_couple as c
  join public.profiles as p
    on p.id = c.user_a_id
    or p.id = c.user_b_id
  order by
    case when p.id = (select auth.uid()) then 0 else 1 end;
$$;

revoke execute on function public.get_active_couple_member_birthdays()
  from public, anon;

grant execute on function public.get_active_couple_member_birthdays()
  to authenticated;
