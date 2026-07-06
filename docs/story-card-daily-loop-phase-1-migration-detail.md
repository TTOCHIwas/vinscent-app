# 스토리 카드 일일 루프 1단계 마이그레이션 상세 설계

작성일: 2026-07-06

본 문서는 `story-card-daily-loop-migration-phase-design.md`에서 정의한 1단계 migration을 실제 SQL로 옮기기 직전 수준까지 쪼개어 정리한 상세 설계 문서이다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-contract-design.md`
- `docs/story-card-daily-loop-physical-schema-design.md`
- `docs/story-card-daily-loop-migration-phase-design.md`

기준 코드:

- `apps/mobile/lib/features/characters/data/couple_character_repository.dart`
- `apps/mobile/lib/features/recordings/data/couple_recording_repository.dart`
- `supabase/migrations/20260601002000_create_couple_characters.sql`
- `supabase/migrations/20260626000000_create_couple_recordings.sql`

---

## 1. 이번 단계의 목적

1단계 migration의 목적은 새 일일 루프 구조를 기존 앱을 깨지 않고 먼저 수용할 수 있는 기반을 만드는 것이다.

이번 단계에서 만들 것은 다음 네 축이다.

1. 새 하루 공용 루트 테이블
2. 사용자별 스토리 카드 테이블
3. 스토리 카드 알림 이벤트 테이블
4. 스토리 카드 storage bucket 및 접근 정책

반대로 이번 단계에서 만들지 않는 것은 다음이다.

1. `daily_questions` 연결 컬럼
2. backfill
3. 새 read RPC
4. 새 write RPC
5. archive purge 확장
6. notification helper 확장

즉 이번 단계는 "새 구조를 담을 그릇을 만드는 단계"로 제한한다.

---

## 2. 먼저 수정하고 가야 하는 설계 포인트

## 2.1 업로드 흐름 추적 결과

현재 프로젝트의 스토리지 업로드 흐름은 다음 두 축에서 동일한 패턴을 보인다.

### 캐릭터 저장

호출 흐름:

1. Flutter repository가 storage path를 먼저 계산
2. `uploadBinary(..., upsert: true)`로 storage 업로드
3. 그 다음 `upsert_couple_character` RPC 호출

### 녹음 저장

호출 흐름:

1. Flutter repository가 `recordingId`를 먼저 생성
2. storage path를 먼저 계산
3. `uploadBinary(..., upsert: false)`로 storage 업로드
4. 그 다음 `replace_current_couple_recording` RPC 호출

즉 이 프로젝트는 "스토리지 업로드 선행, DB 확정 후행" 구조를 이미 사용 중이다.

## 2.2 그래서 기존의 `loop_id/card_id` 경로안은 그대로 쓰면 안 된다

이전에 물리 스키마 초안에서 생각한 아래 경로는 그대로 쓰기 어렵다.

- `{couple_id}/loops/{loop_id}/cards/{card_id}/preview.png`
- `{couple_id}/loops/{loop_id}/cards/{card_id}/scene.json`

이유:

1. upload-first 구조에서는 storage 업로드 시점에 `loop_id`, `card_id`가 아직 확정되지 않는다.
2. `loop_id`를 먼저 만들기 위한 RPC를 추가하면, 1단계에서 의도하지 않은 조기 write 경계 설계가 들어온다.
3. `card_id`까지 사전 생성하려면 draft lifecycle이 필요해지는데, 현재 요구사항 범위를 넘는다.

## 2.3 1단계에서는 deterministic path를 사용한다

현재 요구사항에서 하루 사용자별 카드 제약은 명확하다.

- 커플 기준 하루 1루프
- 사용자 기준 하루 1카드

따라서 storage path는 아래처럼 고정한다.

- `preview_path = {couple_id}/loops/{couple_date}/{author_user_id}/preview.png`
- `scene_data_path = {couple_id}/loops/{couple_date}/{author_user_id}/scene.json`

이 설계의 장점:

1. 클라이언트가 `couple_id`, `couple_date`, `author_user_id`만으로 업로드 경로를 즉시 계산할 수 있다.
2. 질문 생성 전 수정 저장은 같은 경로 overwrite로 처리할 수 있다.
3. 카드 row의 ID와 storage 경로가 결합되지 않아 write 단계가 단순해진다.
4. archive cleanup은 커플/날짜 prefix 기준으로 확장하기 쉽다.

---

## 3. 1단계 migration 산출물

## 3.1 `storage.buckets`

새 bucket:

- `story-cards`

권장 정의:

```sql
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
```

설명:

- preview bitmap과 scene json 저장을 동시에 허용해야 하므로 이미지 + json mime type을 함께 넣는다.
- file size limit은 우선 녹음 bucket과 동일한 5MB로 두는 것이 안전하다.

---

## 3.2 `public.daily_story_loops`

권장 정의:

```sql
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
```

추가 인덱스:

```sql
create index daily_story_loops_couple_date_idx
  on public.daily_story_loops (couple_id, couple_date desc);
```

설명:

- `daily_story_loops_reference_unique`는 3단계에서 `daily_questions`가 자기 `couple_id`, `assigned_date`와 일치하는 루프만 가리키도록 복합 FK를 걸기 위한 참조 키다.

---

## 3.3 `public.story_loop_cards`

권장 정의:

```sql
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
```

추가 인덱스:

```sql
create index story_loop_cards_couple_date_idx
  on public.story_loop_cards (couple_id, couple_date desc, submitted_at asc);

create index story_loop_cards_loop_submitted_idx
  on public.story_loop_cards (story_loop_id, submitted_at asc);
```

설명:

- `story_loop_id + author_user_id` unique로 사용자당 하루 1카드 제약을 유지한다.
- `couple_id`, `couple_date`를 중복 보관해 월간 summary/위젯 fallback/읽기 정책 최적화 여지를 만든다.

---

## 3.4 `public.story_loop_notification_events`

권장 정의:

```sql
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
```

추가 인덱스:

```sql
create index story_loop_notification_events_receiver_created_idx
  on public.story_loop_notification_events (receiver_user_id, created_at desc);
```

설명:

- 1단계에서는 이벤트 테이블만 만든다.
- 실제 helper 함수와 edge function wiring은 다음 단계로 넘긴다.

---

## 4. RLS 및 helper 함수 상세 설계

## 4.1 테이블 select 정책 기준

`daily_story_loops`, `story_loop_cards`의 select는 모두 아래 권위를 따른다.

- `private.is_readable_couple_member(couple_id, auth.uid())`

이유:

- active couple뿐 아니라 disconnected + archive grace 기간 동안도 읽기 전용 열람이 필요하다.

## 4.2 storage select와 storage write 기준은 분리한다

스토리지 정책은 read와 write를 같은 helper로 묶으면 안 된다.

이유:

- read는 readable couple 허용
- write는 active couple만 허용

따라서 helper를 두 개로 나눈다.

### helper 1: readable storage object 판별

권장 이름:

- `private.is_current_user_readable_story_card_storage_object(object_bucket_id text, object_name text)`

역할:

- `story-cards` bucket인지 확인
- 현재 사용자가 readable couple member인지 확인
- object path가 `{couple_id}/loops/{date}/{user_id}/preview.png|scene.json` 패턴인지 확인

### helper 2: writable storage object 판별

권장 이름:

- `private.is_current_user_writable_story_card_storage_object(object_bucket_id text, object_name text)`

역할:

- `story-cards` bucket인지 확인
- 현재 사용자가 active couple member인지 확인
- object path가 현재 사용자의 업로드 허용 패턴인지 확인

## 4.3 정책 정의

### 테이블 정책

```sql
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
```

`story_loop_notification_events`는 앱 사용자 select를 열지 않는다.

### storage 정책

```sql
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
```

설명:

- 수정 저장이 같은 경로 overwrite일 가능성이 높으므로 update 정책이 필요하다.
- recordings처럼 insert-only로 두면 카드 수정 단계에서 막힌다.

---

## 5. trigger / RLS / helper 배치 순서

현재 마이그레이션 컨벤션을 기준으로 1단계 SQL 내부 순서는 아래가 가장 자연스럽다.

1. `storage.buckets` insert
2. 새 테이블 create
3. index create
4. `alter table ... enable row level security`
5. `set_updated_at` trigger create
6. storage helper 함수 create
7. select/storage policy create
8. 필요한 revoke

즉 character migration과 recording migration의 중간 형태를 따른다.

---

## 6. 1단계에서 일부러 보류하는 것

## 6.1 `daily_questions` 연결 금지

1단계에서는 `daily_questions.story_loop_id`를 추가하지 않는다.

이유:

- 새 루트와 기존 질문 루트가 동시에 보이는 혼합 단계에서 문제 추적이 복잡해진다.
- 1단계의 목적은 기반 구조 추가이지 연결 시작이 아니다.

## 6.2 RPC 추가 금지

1단계에서는 아래 RPC를 만들지 않는다.

- `get_today_story_loop_summary`
- `get_story_loop_detail`
- `get_story_loop_month_summary`
- `upsert_today_story_card`
- `delete_today_story_card`

이유:

- 스키마 검증과 read/write 경계 검증을 분리해야 한다.

## 6.3 cleanup helper 추가 금지

1단계에서는 story-card purge helper를 만들지 않는다.

이유:

- `storage_cleanup_requests` 제약 자체가 아직 확장되지 않았기 때문이다.
- 잘못 넣으면 죽은 helper만 먼저 들어간다.

---

## 7. 검증 기준

1단계 migration이 끝나면 최소 아래가 확인되어야 한다.

1. `story-cards` bucket 생성
2. `daily_story_loops` 생성
3. `story_loop_cards` 생성
4. `story_loop_notification_events` 생성
5. `story_loop_cards_preview_path_check` / `scene_data_path_check` 제약 정상 적용
6. readable member는 storage select 가능
7. active member는 storage insert/update 가능
8. disconnected readable member는 storage update 불가

---

## 8. 이 단계에서 잠그는 결론

1단계 migration에서 가장 중요한 설계 잠금은 아래 두 가지이다.

1. storage path는 `loop_id/card_id` 기반이 아니라 `couple_id + couple_date + author_user_id` 기반으로 간다.
2. storage 정책은 read와 write helper를 분리한다.

즉 1단계는 단순히 테이블 세 개를 만드는 작업이 아니라, 현재 프로젝트의 upload-first 저장 패턴과 archive readable 접근 모델을 깨지 않으면서 스토리 카드 구조를 수용하는 기반을 만드는 작업이다.
