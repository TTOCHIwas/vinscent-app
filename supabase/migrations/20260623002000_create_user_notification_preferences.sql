create table public.user_notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  expression_enabled boolean not null default true,
  partner_answer_enabled boolean not null default true,
  daily_question_enabled boolean not null default true,
  reminder_enabled boolean not null default true,
  couple_disconnect_enabled boolean not null default true,
  daily_question_delivery_time time not null default '09:00:00',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_notification_preferences enable row level security;

create trigger user_notification_preferences_set_updated_at
  before update on public.user_notification_preferences
  for each row
  execute function public.set_updated_at();

create policy "user_notification_preferences_select_own"
  on public.user_notification_preferences
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function private.ensure_user_notification_preferences(
  target_user_id uuid
)
returns public.user_notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  ensured_preferences public.user_notification_preferences%rowtype;
begin
  insert into public.user_notification_preferences (user_id)
  values (target_user_id)
  on conflict (user_id) do nothing;

  select *
  into ensured_preferences
  from public.user_notification_preferences
  where user_id = target_user_id;

  return ensured_preferences;
end;
$$;

create or replace function public.get_my_notification_preferences()
returns table (
  user_id uuid,
  expression_enabled boolean,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  daily_question_delivery_time time,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  ensured_preferences public.user_notification_preferences%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  ensured_preferences := private.ensure_user_notification_preferences(current_user_id);

  return query
    select
      ensured_preferences.user_id,
      ensured_preferences.expression_enabled,
      ensured_preferences.partner_answer_enabled,
      ensured_preferences.daily_question_enabled,
      ensured_preferences.reminder_enabled,
      ensured_preferences.couple_disconnect_enabled,
      ensured_preferences.daily_question_delivery_time,
      ensured_preferences.created_at,
      ensured_preferences.updated_at;
end;
$$;

create or replace function public.update_my_notification_preferences(
  requested_expression_enabled boolean,
  requested_partner_answer_enabled boolean,
  requested_daily_question_enabled boolean,
  requested_reminder_enabled boolean,
  requested_couple_disconnect_enabled boolean,
  requested_daily_question_delivery_time time
)
returns table (
  user_id uuid,
  expression_enabled boolean,
  partner_answer_enabled boolean,
  daily_question_enabled boolean,
  reminder_enabled boolean,
  couple_disconnect_enabled boolean,
  daily_question_delivery_time time,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if requested_daily_question_delivery_time is null then
    perform private.raise_app_error('invalid_delivery_time');
  end if;

  perform private.ensure_user_notification_preferences(current_user_id);

  return query
    update public.user_notification_preferences
    set
      expression_enabled = requested_expression_enabled,
      partner_answer_enabled = requested_partner_answer_enabled,
      daily_question_enabled = requested_daily_question_enabled,
      reminder_enabled = requested_reminder_enabled,
      couple_disconnect_enabled = requested_couple_disconnect_enabled,
      daily_question_delivery_time = requested_daily_question_delivery_time
    where public.user_notification_preferences.user_id = current_user_id
    returning
      public.user_notification_preferences.user_id,
      public.user_notification_preferences.expression_enabled,
      public.user_notification_preferences.partner_answer_enabled,
      public.user_notification_preferences.daily_question_enabled,
      public.user_notification_preferences.reminder_enabled,
      public.user_notification_preferences.couple_disconnect_enabled,
      public.user_notification_preferences.daily_question_delivery_time,
      public.user_notification_preferences.created_at,
      public.user_notification_preferences.updated_at;
end;
$$;

revoke execute on function private.ensure_user_notification_preferences(uuid)
  from public, anon, authenticated;
revoke execute on function public.get_my_notification_preferences()
  from public, anon;
revoke execute on function public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  time
)
  from public, anon;

grant execute on function public.get_my_notification_preferences()
  to authenticated;
grant execute on function public.update_my_notification_preferences(
  boolean,
  boolean,
  boolean,
  boolean,
  boolean,
  time
)
  to authenticated;
