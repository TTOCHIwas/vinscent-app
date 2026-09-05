create table public.public_holidays (
  country_code text not null,
  subdivision_code text not null default '',
  holiday_date date not null,
  name text not null,
  source_url text not null,
  source_revision text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint public_holidays_pkey primary key (
    country_code,
    subdivision_code,
    holiday_date,
    name
  ),
  constraint public_holidays_country_code_check
    check (country_code ~ '^[A-Z]{2}$'),
  constraint public_holidays_name_check
    check (char_length(btrim(name)) between 1 and 80)
);

alter table public.public_holidays enable row level security;

create policy "public_holidays_select_authenticated"
  on public.public_holidays
  for select
  to authenticated
  using (true);

revoke all on table public.public_holidays from anon, authenticated;
grant select on table public.public_holidays to authenticated;

comment on table public.public_holidays is
  'Operational public-holiday read model. Application clients can only read.';

insert into public.public_holidays (
  country_code,
  holiday_date,
  name,
  source_url,
  source_revision
)
values
  ('KR', '2025-01-01', '신정', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-01-28', '설날 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-01-29', '설날', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-01-30', '설날 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-03-01', '삼일절', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-03-03', '대체공휴일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-05-05', '어린이날 · 부처님오신날', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-05-06', '대체공휴일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-06-03', '대통령 선거일', 'https://www.data.go.kr/data/15012690/openapi.do', '2025-special-holiday'),
  ('KR', '2025-06-06', '현충일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-08-15', '광복절', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-10-03', '개천절', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-10-05', '추석 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-10-06', '추석', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-10-07', '추석 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-10-08', '대체공휴일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-10-09', '한글날', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2025-12-25', '기독탄신일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000000633Wg5pO7', '2025-monthly-almanac'),
  ('KR', '2026-01-01', '신정', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-02-16', '설날 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-02-17', '설날', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-02-18', '설날 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-03-01', '삼일절', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-03-02', '대체공휴일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-05-01', '노동절', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2026-public-holiday-amendment'),
  ('KR', '2026-05-05', '어린이날', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-05-24', '부처님오신날', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-05-25', '대체공휴일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-06-03', '전국동시지방선거일', 'https://www.data.go.kr/data/15012690/openapi.do', '2026-election-holiday'),
  ('KR', '2026-06-06', '현충일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-07-17', '제헌절', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2026-public-holiday-amendment'),
  ('KR', '2026-08-15', '광복절', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-08-17', '대체공휴일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-09-24', '추석 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-09-25', '추석', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-09-26', '추석 연휴', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-10-03', '개천절', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-10-05', '대체공휴일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-10-09', '한글날', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2026-12-25', '기독탄신일', 'https://www.kasa.go.kr/prog/bbsArticle/BBSMSTR_000000000010/view.do?bbsId=BBSMSTR_000000000010&nttId=B000000001860Pe2zT3', '2026-monthly-almanac-amended'),
  ('KR', '2027-01-01', '신정', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-02-06', '설날 연휴', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-02-07', '설날', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-02-08', '설날 연휴', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-02-09', '대체공휴일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-03-01', '삼일절', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-05-01', '노동절', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-05-03', '대체공휴일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-05-05', '어린이날', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-05-13', '부처님오신날', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-06-06', '현충일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-07-17', '제헌절', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-07-19', '대체공휴일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-08-15', '광복절', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-08-16', '대체공휴일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-09-14', '추석 연휴', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-09-15', '추석', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-09-16', '추석 연휴', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-10-03', '개천절', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-10-04', '대체공휴일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-10-09', '한글날', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-10-11', '대체공휴일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-12-25', '기독탄신일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac'),
  ('KR', '2027-12-27', '대체공휴일', 'https://www.kasa.go.kr/prog/plcyBrf/brief/kor/sub01_01_04/view.do?plcyBrfNo=431', '2027-monthly-almanac')
on conflict on constraint public_holidays_pkey do update
set
  source_url = excluded.source_url,
  source_revision = excluded.source_revision,
  updated_at = now();

create function public.get_couple_calendar_events_for_device_sync(
  target_start_date date
)
returns table (
  event_id uuid,
  couple_id uuid,
  title text,
  event_date date,
  occurrence_date date,
  repeat_rule text,
  memo text,
  artwork_preview_path text,
  artwork_data_path text,
  revision integer,
  created_by_user_id uuid,
  updated_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  own_reminder_enabled boolean,
  own_reminder_offset_days integer,
  own_reminder_time time
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  readable_couple public.couples%rowtype;
begin
  if current_user_id is null then
    perform private.raise_app_error('auth_required');
  end if;

  if target_start_date is null then
    perform private.raise_app_error('invalid_calendar_event_date');
  end if;

  readable_couple := private.get_readable_couple_for_current_user();

  return query
    select
      cce.id,
      cce.couple_id,
      cce.title,
      cce.event_date,
      cce.event_date,
      cce.repeat_rule,
      cce.memo,
      cce.artwork_preview_path,
      cce.artwork_data_path,
      cce.revision,
      cce.created_by_user_id,
      cce.updated_by_user_id,
      cce.created_at,
      cce.updated_at,
      coalesce(ccer.is_enabled, false),
      coalesce(ccer.offset_days, 0),
      coalesce(ccer.reminder_time, '09:00:00'::time)
    from public.couple_calendar_events as cce
    left join public.couple_calendar_event_reminders as ccer
      on ccer.event_id = cce.id
      and ccer.user_id = current_user_id
    where cce.couple_id = readable_couple.id
      and (
        cce.repeat_rule = 'yearly'
        or cce.event_date >= target_start_date
      )
    order by cce.event_date, cce.created_at, cce.id;
end;
$$;

revoke all on function public.get_couple_calendar_events_for_device_sync(date)
  from public, anon;
grant execute on function public.get_couple_calendar_events_for_device_sync(date)
  to authenticated;
