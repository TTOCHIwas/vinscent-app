create function public.has_couple_calendar_event_occurrence(
  target_date date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  readable_couple public.couples%rowtype;
  target_year integer;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if target_date is null
    or target_date < date '0001-01-01'
    or target_date > date '2100-12-31'
  then
    perform private.raise_app_error('invalid_calendar_event_date');
  end if;

  readable_couple := private.get_readable_couple_for_current_user();

  if readable_couple.relationship_start_date is null then
    perform private.raise_app_error('relationship_date_required');
  end if;

  if target_date < readable_couple.relationship_start_date then
    return false;
  end if;

  target_year := extract(year from target_date)::integer;

  return exists (
    select 1
    from public.couple_calendar_events as calendar_event
    where calendar_event.couple_id = readable_couple.id
      and calendar_event.event_date <= target_date
      and (
        (
          calendar_event.repeat_rule = 'none'
          and calendar_event.event_date = target_date
        )
        or
        (
          calendar_event.repeat_rule = 'yearly'
          and target_date = private.calendar_event_occurrence_date(
            calendar_event.event_date,
            target_year
          )
        )
      )
  );
end;
$$;

revoke all on function public.has_couple_calendar_event_occurrence(date)
  from public, anon;

grant execute on function public.has_couple_calendar_event_occurrence(date)
  to authenticated;
