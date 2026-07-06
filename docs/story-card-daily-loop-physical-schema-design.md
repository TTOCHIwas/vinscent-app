# 스토리 카드 일일 루프 물리 스키마 설계

작성일: 2026-07-06

본 문서는 아래 문서와 현재 Supabase 마이그레이션을 기준으로, 스토리 카드 기반 일일 루프를 실제 DB 스키마로 어떻게 내려놓을지 정리한 물리 설계 문서이다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-contract-design.md`

기준 마이그레이션:

- `supabase/migrations/20260531000000_create_couples.sql`
- `supabase/migrations/20260531002000_create_daily_questions.sql`
- `supabase/migrations/20260531006000_create_daily_question_answers.sql`
- `supabase/migrations/20260623000000_add_couple_archive_lifecycle.sql`
- `supabase/migrations/20260623001000_add_readable_access_and_couple_timezone_dates.sql`
- `supabase/migrations/20260626000000_create_couple_recordings.sql`

---

## 1. 설계 목표

이번 물리 스키마 설계의 목표는 다음 네 가지이다.

1. 기존 `daily_questions` 중심 구조 위에 질문보다 먼저 존재하는 하루 공용 루트를 추가한다.
2. 스토리 카드를 질문의 부모가 아니라 하루 공용 루트의 자식으로 둔다.
3. 기존 질문/답변 UI와 RPC를 한 번에 제거하지 않고, 하위 단계로 내린 채 공존시킨다.
4. 월간 캘린더, 홈, 위젯, 읽기 전용 보관 상태까지 감당할 수 있는 조회 축을 확보한다.

---

## 2. 현재 구조에서 확인된 사실

### 2.1 현재 하루 공용 루트는 `daily_questions`

현재 실제 호출 흐름은 아래와 같다.

- 홈 읽기: `home_screen.dart` -> `questionDetailProvider` -> `todayQuestionControllerProvider` -> `fetchTodayQuestion()` -> `get_or_assign_today_question()`
- 답변 저장: `today_question_answer_screen.dart` -> `todayAnswerController` -> `submit_today_question_answer()`
- 캘린더 상세: `calendar_screen.dart` -> `dailyQuestionHistoryProvider` -> `get_daily_question_answer_state_for_date()`

즉 현재는 하루 공용 단위를 `daily_questions`가 대표하고 있다.

### 2.2 새 요구사항에서는 질문보다 먼저 하루 루트가 필요함

요구사항 기준으로 하루 루프는 다음 순서를 갖는다.

1. 사용자 A 카드 저장
2. 사용자 B 카드 저장
3. 질문 생성
4. 각자 답변 저장

따라서 질문은 루트가 아니라 루트 아래에서 파생되는 자식 상태가 되어야 한다.

### 2.3 이 프로젝트는 이미 "공용 aggregate + 자식 row + 이벤트 row" 패턴을 사용 중임

`20260626000000_create_couple_recordings.sql` 기준 녹음 기능은 아래 구조를 사용한다.

- 공용 설정: `couple_recording_slot_settings`
- 공용 현재 상태: `couple_current_recordings`
- 자식 데이터: `couple_recordings`, `couple_recording_slots`
- 이벤트 큐: `recording_notification_events`

스토리 카드도 같은 구조적 접근이 프로젝트 컨벤션에 더 가깝다.

---

## 3. 최상위 스키마 결정

### 3.1 새 하루 공용 루트 테이블을 추가한다

새 루트 테이블 이름은 다음으로 고정한다.

- `public.daily_story_loops`

이 테이블이 표현하는 것은 "커플의 특정 날짜 하루 루프 상태"이다.

### 3.2 `daily_questions`는 삭제하지 않고 자식으로 강등한다

기존 `public.daily_questions`는 제거하지 않는다.

이유:

1. 기존 질문/답변 UI가 이미 이 테이블에 묶여 있다.
2. 캘린더, 질문 상세, 답변 저장 로직을 한 번에 걷어내면 전환 리스크가 너무 크다.
3. 스토리 카드 전환 1차 구현의 핵심은 질문 생성 시점을 뒤로 미루는 것이지, 질문 도메인을 즉시 제거하는 것이 아니다.

따라서 `daily_questions`는 앞으로 `daily_story_loops` 아래에서 생성되는 자식 엔티티가 된다.

### 3.3 스토리 카드는 사용자별 자식 테이블로 둔다

스토리 카드 테이블 이름은 다음으로 고정한다.

- `public.story_loop_cards`

이 테이블은 하루 루트 아래에서 사용자별 카드 결과물을 저장한다.

---

## 4. 테이블 설계

## 4.1 `public.daily_story_loops`

### 역할

- 커플의 하루 공용 루트
- 카드 개수, 질문 생성 여부, 답변 진행 상태의 상위 권위

### 컬럼

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

### 상태 해석

- row 없음: `empty`
- row 있음 + `waiting_partner_card`: 카드 1장만 존재
- row 있음 + `question_generated`: 카드 2장 완료, 질문 생성 완료
- row 있음 + `answered_by_one`: 질문 생성 후 답변 1개 완료
- row 있음 + `completed`: 질문 생성 후 답변 2개 완료

### 인덱스

```sql
create index daily_story_loops_couple_date_idx
  on public.daily_story_loops (couple_id, couple_date desc);
```

### 비고

- `couple_date`는 `private.current_date_in_timezone(couple.timezone)` 기준으로 write 시점에 계산한다.
- `story_edit_locked_at`는 질문 생성 직후 채워진다.
- `daily_story_loops_reference_unique`는 이후 `daily_questions`의 복합 FK 참조 키로 사용된다.

---

## 4.2 `public.story_loop_cards`

### 역할

- 하루 루트 아래의 사용자별 스토리 카드
- 사진/드로잉/텍스트 조합 결과물의 최종 저장 단위

### 컬럼

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

### 왜 `couple_id`, `couple_date`를 중복 보관하는가

`story_loop_id`만으로도 조인은 가능하지만, 현재 요구사항에서는 아래 조회가 반복된다.

1. 월간 캘린더에서 날짜별 카드 0..2장 조회
2. 위젯에서 상대방 최근 카드 조회
3. 홈에서 오늘 카드 0..2장 조회
4. 읽기 전용 보관 상태에서 커플 기준 카드 접근 허용

이 조회를 전부 부모 조인만으로 처리하면 부모 루트 조인이 과도하게 많아진다.  
따라서 읽기 최적화와 RLS 단순화를 위해 `couple_id`, `couple_date`를 자식에도 직접 둔다.

이 패턴은 이미 녹음 테이블들이 공용 상위 키를 직접 들고 가는 방식과도 맞다.

### 인덱스

```sql
create index story_loop_cards_couple_date_idx
  on public.story_loop_cards (couple_id, couple_date desc, submitted_at asc);

create index story_loop_cards_loop_submitted_idx
  on public.story_loop_cards (story_loop_id, submitted_at asc);
```

### 비고

- `preview_path`는 홈/캘린더/위젯 공통 미리보기 렌더 결과물을 가리킨다.
- `scene_data_path`는 편집 재진입용 원본 scene 데이터를 가리킨다.
- 사진, 드로잉, 텍스트를 각각 서브테이블로 쪼개지 않고 scene 단일 payload로 관리한다.
- storage path는 `loop_id`, `card_id`가 아니라 `couple_id + couple_date + author_user_id` 조합으로 고정한다.

### 왜 storage path에 `loop_id`, `card_id`를 넣지 않는가

현재 이 프로젝트의 업로드 흐름은 캐릭터와 녹음 모두 아래 순서를 따른다.

1. 클라이언트가 storage path를 먼저 만든다.
2. storage에 바이너리를 먼저 업로드한다.
3. 이후 RPC로 DB row를 확정한다.

즉 스토리 카드도 같은 upload-first 패턴을 따를 가능성이 높다.  
이 경우 `loop_id`, `card_id`가 DB write 이전에 아직 존재하지 않으므로, storage path가 그 ID를 요구하면 업로드 경로를 결정할 수 없다.

반면 현재 요구사항은 "사용자당 하루 1카드" 제약이 명확하다.  
따라서 storage path를 아래처럼 날짜+사용자 조합으로 고정하면 upload-first 구조와 잘 맞는다.

- `preview_path = {couple_id}/loops/{couple_date}/{author_user_id}/preview.png`
- `scene_data_path = {couple_id}/loops/{couple_date}/{author_user_id}/scene.json`

이 방식이면:

1. 클라이언트가 서버에서 받은 `couple_date`와 이미 알고 있는 `couple_id`, `author_user_id`로 path를 즉시 계산할 수 있다.
2. 같은 날 수정 저장은 `upsert: true`로 같은 경로를 덮어쓸 수 있다.
3. 질문 생성 후 수정 잠금이 걸리면 더 이상 update를 막으면 된다.
4. archive purge는 `couple_id/loops/` prefix 기준으로 정리할 수 있다.

---

## 4.3 `public.daily_questions` 확장

### 역할 변화

기존: 하루 공용 루트  
변경 후: 하루 루트 아래에서 생성되는 질문 자식

### 추가 컬럼

```sql
alter table public.daily_questions
  add column story_loop_id uuid
;

alter table public.daily_questions
  add constraint daily_questions_story_loop_match_fkey
    foreign key (couple_id, assigned_date, story_loop_id)
    references public.daily_story_loops(couple_id, couple_date, id)
    on delete cascade;
```

### 최종 제약 목표

```sql
alter table public.daily_questions
  alter column story_loop_id set not null;

alter table public.daily_questions
  add constraint daily_questions_story_loop_unique
    unique (story_loop_id);
```

### 유지할 컬럼

- `couple_id`
- `question_id`
- `assigned_date`
- `status`

### 유지 이유

- 기존 질문 상세/답변/캘린더 하위 로직과의 호환성 유지
- 전환 기간 동안 기존 쿼리와 신규 쿼리를 함께 버틸 수 있음

### 중요 원칙

- 하루 루트의 authoritative status는 `daily_story_loops.status`
- `daily_questions.status`는 하위 질문 단계와의 호환용 동기화 상태
- `story_loop_id`가 채워진 질문 row는 반드시 자기 `couple_id`, `assigned_date`와 일치하는 루프만 가리켜야 한다.

---

## 4.4 `public.story_loop_notification_events`

### 역할

- 스토리 카드 관련 푸시 이벤트 큐
- Edge Function이 polling 또는 webhook 형태로 소비하는 트리거 원천

### 컬럼

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

### 인덱스

```sql
create index story_loop_notification_events_receiver_created_idx
  on public.story_loop_notification_events (receiver_user_id, created_at desc);
```

### 비고

- 상대 답변 완료 알림은 기존 `daily_question_answers` 축 이벤트를 재사용할 수 있으므로 분리 유지한다.

---

## 5. 스토리지 설계

## 5.1 버킷

스토리 카드 전용 private bucket을 둔다.

- 버킷명 후보: `story-cards`

### 저장 경로 규칙

- preview: `{couple_id}/loops/{couple_date}/{author_user_id}/preview.png`
- scene: `{couple_id}/loops/{couple_date}/{author_user_id}/scene.json`

### 이유

1. 커플 단위 prefix 조회가 쉬움
2. loop/card 단위 cleanup이 쉬움
3. disconnect 30일 보관 후 purge 경로와 맞음

## 5.2 DB에는 경로만 저장

DB에는 binary 자체를 넣지 않고 다음만 보관한다.

- `preview_path`
- `scene_data_path`

이 프로젝트는 녹음, 캐릭터도 storage path 참조 방식이므로 일관성이 유지된다.

---

## 6. RLS 및 접근 권한 설계

## 6.1 읽기 기준

읽기 기준은 기존 readable couple helper를 그대로 따른다.

사용 함수:

- `private.is_readable_couple_member(uuid, uuid)`
- `private.get_readable_couple_for_current_user()`

즉 아래 상태에서 읽기 허용:

- `pending`
- `active`
- `disconnected` + `archive_expires_at > now()`

## 6.2 쓰기 기준

쓰기 기준은 active couple만 허용한다.

스토리 카드 생성/수정/삭제는 아래 helper 축을 따른다.

- `private.get_active_couple_for_current_user()`

읽기 전용 보관 상태에서는 스토리 카드 수정 불가, 조회만 허용한다.

## 6.3 정책 방향

### `daily_story_loops`

- `select`: `private.is_readable_couple_member(couple_id, auth.uid())`
- `insert/update/delete`: 직접 정책보다 security definer RPC만 허용하는 쪽이 안전

### `story_loop_cards`

- `select`: `private.is_readable_couple_member(couple_id, auth.uid())`
- `insert/update/delete`: 직접 DML 금지, RPC 전용

### `story_loop_notification_events`

- 앱 사용자 select 불필요
- service role 또는 함수 전용

---

## 7. 쓰기 경계와 스키마의 연결

## 7.1 `upsert_today_story_card`

이 RPC는 다음 순서로 동작해야 한다.

1. auth
2. active couple 조회
3. timezone 기준 `couple_date` 계산
4. `(couple_id, couple_date)` advisory lock
5. `daily_story_loops` 조회/생성
6. `story_loop_cards` 내 내 카드 upsert
7. 카드 수 재계산
8. 카드 수 1 -> `waiting_partner_card`
9. 카드 수 2 + 질문 없음 -> `daily_questions` 생성
10. `daily_story_loops.status = 'question_generated'`
11. `story_edit_locked_at` 설정
12. 알림 이벤트 적재

## 7.2 `delete_today_story_card`

1. auth
2. active couple 조회
3. 오늘 루프 조회
4. advisory lock
5. 질문 이미 생성됨 -> 실패
6. 내 카드 삭제
7. 카드 수 재계산
8. 남은 카드 1 -> `waiting_partner_card`
9. 남은 카드 0 -> loop row 삭제

## 7.3 `submit_today_question_answer`

기존과 달라지는 점은 질문 생성 책임이 완전히 제거된다는 점이다.

1. auth
2. active couple 조회
3. timezone 기준 오늘 날짜 계산
4. 오늘 `daily_story_loops` 조회
5. `status in ('question_generated', 'answered_by_one', 'completed')` 검증
6. 연결된 `daily_questions` 존재 검증
7. 기존 답변 upsert
8. 답변 수 재계산
9. `daily_questions.status` 갱신
10. `daily_story_loops.status` 동기화

---

## 8. 월간 캘린더와 위젯 관점에서의 설계 이점

## 8.1 월간 캘린더

월간 캘린더는 날짜별 카드 0..2장을 빠르게 읽어야 한다.  
`story_loop_cards`에 `couple_id`, `couple_date`, `submitted_at`이 직접 있으므로 부모 루트 없이도 summary 집계를 효율적으로 만들 수 있다.

즉 월간 grid는 아래 두 레이어 중 선택 구현이 가능하다.

1. `daily_story_loops` + `story_loop_cards` 조합 RPC
2. `story_loop_cards` 중심 집계 RPC

현재 요구사항 기준으로는 1번이 기본이지만, 성능 이슈가 생기면 2번 최적화 여지도 남긴다.

## 8.2 위젯

위젯은 "상대가 최근 올린 카드" fallback이 필요하다.  
이 요구사항은 카드가 질문의 자식이면 구현이 어색해지지만, 카드가 별도 자식 테이블이면 자연스럽다.

예:

- 오늘 카드 있으면 오늘 카드 상태 표시
- 오늘 카드 없으면 `author_user_id <> current_user_id` 조건의 최신 카드 1장 fallback

---

## 9. 마이그레이션 단계 설계

## 9.1 1단계: 테이블 추가

새로 추가:

- `daily_story_loops`
- `story_loop_cards`
- `story_loop_notification_events`
- storage bucket 및 policy

이 단계에서는 기존 질문 흐름은 건드리지 않는다.

## 9.2 2단계: `daily_questions` 연결 컬럼 추가

- `daily_questions.story_loop_id` nullable 추가

초기에는 nullable로 둔다.

이유:

- 과거 질문 데이터는 아직 루프 row가 없기 때문
- backfill 전까지 배포 가능 상태 유지 필요

## 9.3 3단계: 기존 질문 write 경로 브리지

- 질문 생성용 loop helper 추가
- 실제 생성 원천 helper인 `private.get_or_assign_daily_question_for_couple()` 브리지화
- `private.get_or_assign_today_daily_question()`는 thin wrapper 유지

이 단계의 목적은 새 null `story_loop_id`가 더 이상 생기지 않도록 live write 경로를 먼저 잠그는 것이다.

## 9.4 4단계: 과거 데이터 backfill

과거 `daily_questions`를 기준으로:

1. `(couple_id, assigned_date)`마다 `daily_story_loops` 생성
2. `daily_questions.story_loop_id` 채우기
3. cardless bridge / historical loop status를 질문 status에 맞춰 정규화

주의:

- 과거에는 카드 데이터가 없으므로 backfill loop는 카드 없는 historical-question loop가 된다.
- 이 과거 데이터는 새 홈 today summary의 기준이 아니라 캘린더/상세 호환용 이력 데이터로 본다.

## 9.5 5단계: 제약 강화

backfill 완료 후:

- `daily_questions.story_loop_id set not null`
- `unique (story_loop_id)`

## 9.6 6단계: 신규 RPC 배포

추가:

- `get_today_story_loop_summary`
- `get_story_loop_detail`
- `get_story_loop_month_summary`
- `upsert_today_story_card`
- `delete_today_story_card`

수정:

- `submit_today_question_answer`

---

## 10. 보존되는 것과 바뀌는 것

## 10.1 보존되는 것

- `couples`의 권위
- timezone 기반 현재 날짜 계산 방식
- readable/archive 접근 모델
- 기존 `questions` curated pool
- 기존 `daily_question_answers` 저장 구조
- 기존 answer-complete 알림 흐름

## 10.2 바뀌는 것

- 하루 공용 루트
- 질문 생성 시점
- 홈의 최상위 상태 공급 구조
- 캘린더의 하루 대표 콘텐츠
- 카드 기반 알림 이벤트 축

---

## 11. 최종 결론

현재 코드 기준으로 가장 안전하고 확장 가능한 구조는 다음과 같다.

1. 새 부모 루트 `daily_story_loops`를 추가한다.
2. 사용자별 카드 `story_loop_cards`를 그 아래 둔다.
3. `daily_questions`는 제거하지 않고 자식으로 내린다.
4. 카드 업로드 2장 완료 시점에만 질문을 생성한다.
5. 읽기 모델은 홈/월간/상세로 분리하되, 물리 스키마는 공용 하루 루트 하나를 기준으로 맞춘다.

이 설계는 현재 프로젝트의 `couples` 권위 구조, archive readable 접근 모델, recording 기능의 aggregate 패턴과 충돌하지 않는다.
