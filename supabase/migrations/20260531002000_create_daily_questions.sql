create table public.questions (
  id uuid primary key default gen_random_uuid(),
  source text not null default 'curated',
  question_text text not null,
  category text not null default 'daily',
  mood text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint questions_source_check
    check (source in ('curated', 'ai')),
  constraint questions_question_text_not_blank
    check (char_length(btrim(question_text)) > 0),
  constraint questions_source_question_text_unique
    unique (source, question_text)
);

create table public.daily_questions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  assigned_date date not null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint daily_questions_status_check
    check (status in ('pending', 'answered_by_one', 'completed')),
  constraint daily_questions_assigned_date_not_future
    check (assigned_date <= private.current_app_date()),
  constraint daily_questions_couple_date_unique
    unique (couple_id, assigned_date)
);

create index daily_questions_couple_date_idx
  on public.daily_questions (couple_id, assigned_date desc);

create index daily_questions_question_id_idx
  on public.daily_questions (question_id);

alter table public.questions enable row level security;
alter table public.daily_questions enable row level security;

create policy "questions_select_active_authenticated"
  on public.questions
  for select
  to authenticated
  using (is_active = true);

create policy "daily_questions_select_couple_member"
  on public.daily_questions
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.couples
      where public.couples.id = daily_questions.couple_id
        and public.couples.status = 'active'
        and (
          public.couples.user_a_id = (select auth.uid())
          or public.couples.user_b_id = (select auth.uid())
        )
    )
  );

create trigger questions_set_updated_at
  before update on public.questions
  for each row
  execute function public.set_updated_at();

create trigger daily_questions_set_updated_at
  before update on public.daily_questions
  for each row
  execute function public.set_updated_at();

create or replace function private.get_active_couple_for_current_user()
returns public.couples
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  active_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  select *
  into active_couple
  from public.couples
  where status = 'active'
    and (user_a_id = current_user_id or user_b_id = current_user_id)
  order by created_at desc
  limit 1;

  if not found then
    perform private.raise_app_error('active_couple_required');
  end if;

  return active_couple;
end;
$$;

create or replace function public.get_or_assign_today_question()
returns table (
  daily_question_id uuid,
  couple_id uuid,
  question_id uuid,
  question_text text,
  question_source text,
  question_category text,
  question_mood text,
  assigned_date date,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_couple public.couples%rowtype;
  app_today date := private.current_app_date();
  assignment_count integer;
  active_question_count integer;
  selected_question_id uuid;
begin
  active_couple := private.get_active_couple_for_current_user();

  perform pg_advisory_xact_lock(
    hashtext('daily_question'),
    hashtext(active_couple.id::text || ':' || app_today::text)
  );

  if exists (
    select 1
    from public.daily_questions
    where public.daily_questions.couple_id = active_couple.id
      and public.daily_questions.assigned_date = app_today
  ) then
    return query
      select
        public.daily_questions.id,
        public.daily_questions.couple_id,
        public.questions.id,
        public.questions.question_text,
        public.questions.source,
        public.questions.category,
        public.questions.mood,
        public.daily_questions.assigned_date,
        public.daily_questions.status
      from public.daily_questions
      join public.questions
        on public.questions.id = public.daily_questions.question_id
      where public.daily_questions.couple_id = active_couple.id
        and public.daily_questions.assigned_date = app_today;

    return;
  end if;

  select count(*)
  into active_question_count
  from public.questions
  where source = 'curated'
    and is_active = true;

  if active_question_count = 0 then
    perform private.raise_app_error('question_pool_empty');
  end if;

  select count(*)
  into assignment_count
  from public.daily_questions
  where public.daily_questions.couple_id = active_couple.id;

  select public.questions.id
  into selected_question_id
  from public.questions
  where source = 'curated'
    and is_active = true
    and not exists (
      select 1
      from public.daily_questions
      where public.daily_questions.couple_id = active_couple.id
        and public.daily_questions.question_id = public.questions.id
    )
  order by public.questions.created_at, public.questions.id
  limit 1;

  if selected_question_id is null then
    select public.questions.id
    into selected_question_id
    from public.questions
    where source = 'curated'
      and is_active = true
    order by public.questions.created_at, public.questions.id
    offset assignment_count % active_question_count
    limit 1;
  end if;

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date
  )
  values (
    active_couple.id,
    selected_question_id,
    app_today
  )
  on conflict (couple_id, assigned_date) do nothing;

  return query
    select
      public.daily_questions.id,
      public.daily_questions.couple_id,
      public.questions.id,
      public.questions.question_text,
      public.questions.source,
      public.questions.category,
      public.questions.mood,
      public.daily_questions.assigned_date,
      public.daily_questions.status
    from public.daily_questions
    join public.questions
      on public.questions.id = public.daily_questions.question_id
    where public.daily_questions.couple_id = active_couple.id
      and public.daily_questions.assigned_date = app_today;
end;
$$;

revoke execute on function private.get_active_couple_for_current_user()
  from public, anon, authenticated;
revoke execute on function public.get_or_assign_today_question()
  from public, anon;

grant execute on function public.get_or_assign_today_question()
  to authenticated;

insert into public.questions (source, question_text, category, mood)
values
  ('curated', '오늘 서로에게 가장 고마웠던 순간은 언제였어?', 'daily', 'warm'),
  ('curated', '처음 만났을 때 기억나는 장면 하나를 말해줘.', 'memory', 'warm'),
  ('curated', '요즘 우리가 같이 해보면 좋을 작은 일은 뭐야?', 'future', 'light'),
  ('curated', '상대방의 귀여운 습관 하나를 꼽는다면?', 'daily', 'light'),
  ('curated', '오늘 상대방에게 듣고 싶은 말은 뭐야?', 'care', 'warm'),
  ('curated', '우리 둘만 아는 웃긴 순간이 있다면?', 'playful', 'light'),
  ('curated', '이번 주에 서로를 위해 해줄 수 있는 작은 배려는?', 'care', 'warm'),
  ('curated', '상대방과 닮고 싶은 점은 뭐야?', 'daily', 'deep'),
  ('curated', '함께 가보고 싶은 장소 하나를 골라줘.', 'future', 'light'),
  ('curated', '요즘 상대방에게 더 자주 표현하고 싶은 마음은?', 'care', 'warm'),
  ('curated', '우리 관계에서 제일 든든하게 느껴지는 순간은?', 'daily', 'deep'),
  ('curated', '처음 설렜던 순간을 한 문장으로 적어줘.', 'memory', 'warm'),
  ('curated', '상대방이 오늘 힘을 낼 수 있게 한마디 한다면?', 'care', 'warm'),
  ('curated', '같이 먹고 싶은 음식 하나를 고른다면?', 'playful', 'light'),
  ('curated', '우리의 다음 데이트에 꼭 넣고 싶은 코스는?', 'future', 'light'),
  ('curated', '상대방이 최근에 멋있어 보였던 순간은?', 'daily', 'warm'),
  ('curated', '우리 둘의 분위기를 색으로 표현하면?', 'playful', 'light'),
  ('curated', '서로에게 더 편해졌다고 느낀 순간은?', 'memory', 'deep'),
  ('curated', '오늘 하루를 상대방에게 선물한다면 어떤 제목을 붙일래?', 'playful', 'light'),
  ('curated', '상대방에게 오래 기억되었으면 하는 내 모습은?', 'daily', 'deep'),
  ('curated', '우리가 함께 만든 좋은 습관이 있다면?', 'memory', 'warm'),
  ('curated', '다음 한 달 동안 같이 이루고 싶은 작은 목표는?', 'future', 'warm'),
  ('curated', '상대방의 어떤 말투가 가장 좋게 느껴져?', 'daily', 'light'),
  ('curated', '오늘의 우리에게 필요한 다정한 약속은 뭐야?', 'care', 'warm')
on conflict (source, question_text) do nothing;
