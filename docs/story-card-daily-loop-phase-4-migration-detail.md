# 스토리 카드 일일 루프 4단계 마이그레이션 상세 설계

작성일: 2026-07-06

본 문서는 4단계 마이그레이션을 기존 설계의 backfill 단계가 아니라, 기존 질문 write 경로를 새 루프 구조에 브리지하는 단계로 재정의한 상세 설계 문서다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-physical-schema-design.md`
- `docs/story-card-daily-loop-migration-phase-design.md`
- `docs/story-card-daily-loop-phase-3-migration-detail.md`

기준 마이그레이션:

- `supabase/migrations/20260531006000_create_daily_question_answers.sql`
- `supabase/migrations/20260601000000_reveal_completed_daily_question_answers.sql`
- `supabase/migrations/20260623004000_add_service_role_notification_helpers.sql`
- `supabase/migrations/20260706002000_link_daily_questions_to_story_loops.sql`

---

## 1. 이번 단계의 목적

4단계의 목적은 기존 질문 생성 경로가 더 이상 null `story_loop_id`를 만들지 못하게 막는 것이다.

이번 단계에서 해결해야 하는 문제는 아래와 같다.

1. 사용자 경로의 `public.get_or_assign_today_question()`은 `private.get_or_assign_today_daily_question()`을 호출한다.
2. `public.get_today_question_answer_state()`도 같은 today helper를 호출한다.
3. `public.submit_today_question_answer(text)`도 같은 today helper를 호출한다.
4. 하지만 그 today helper의 실제 row 생성은 `private.get_or_assign_daily_question_for_couple()`에 위임된다.
5. service role 경로의 `public.get_or_assign_daily_question_for_couple(...)`도 같은 private helper를 호출한다.
6. 그런데 현재 최신 private helper는 `daily_questions` insert 시 `story_loop_id`를 채우지 않는다.

즉 backfill을 먼저 해도, live traffic과 service role traffic이 다시 null row를 만들 수 있다.

따라서 4단계는 과거 데이터 이관 단계가 아니라, live write 차단 단계여야 한다.

---

## 2. 현재 코드 기준 메서드 추적

### 2.1 caller

현재 실제 caller는 아래 네 가지다.

1. `public.get_or_assign_today_question()`
2. `public.get_today_question_answer_state()`
3. `public.submit_today_question_answer(text)`
4. `public.get_or_assign_daily_question_for_couple(requested_couple_id, requested_target_date)`

### 2.2 actual method in use

사용자 경로 세 caller는 모두 `private.get_or_assign_today_daily_question()`에 위임한다.

하지만 현재 최신 구조에서 실제 질문 row 생성 책임은 아래 helper에 있다.

- `private.get_or_assign_daily_question_for_couple(requested_couple_id uuid, requested_target_date date)`

`private.get_or_assign_today_daily_question()`는 이 helper에 오늘 날짜를 계산해 위임하는 thin wrapper다.

### 2.3 missing bridge

현재 빠져 있는 것은 질문 row와 루프 row 사이의 생성 시점 브리지다.

필요한 흐름은 아래와 같아야 한다.

1. 특정 커플/날짜의 질문 row가 이미 있으면 그대로 읽는다.
2. 단, 그 row의 `story_loop_id`가 null이면 즉시 복구한다.
3. 질문 row가 없으면 먼저 해당 커플/날짜의 loop를 확보한다.
4. 그 다음 `story_loop_id`를 채운 상태로 `daily_questions`를 insert 한다.

### 2.4 root cause

근원지는 `daily_questions`와 `daily_story_loops`의 연결 컬럼이 없는 것이 아니라, 연결 컬럼이 생긴 뒤에도 실제 생성 helper가 그것을 사용하지 않는다는 점이다.

따라서 4단계는 테이블 설계가 아니라, 실제 생성 원천 helper 동작을 바꾸는 단계다.

---

## 3. 이번 단계 요구사항

### 3.1 기존 질문 기능은 보존한다

아래 동작은 바꾸지 않는다.

1. 기존 public 질문 RPC 시그니처
2. 기존 service role 질문 RPC 시그니처
3. 오늘 질문 선택 방식
4. 중복 질문 방지 방식
5. advisory lock 범위
6. 커플 timezone 기준 날짜 계산 규칙
7. `daily_questions.status` 초기값과 답변 후 갱신 의미

### 3.2 새 질문 row는 항상 유효한 loop를 참조해야 한다

새 질문 row를 insert 할 때는 반드시 아래가 선행되어야 한다.

1. `(couple_id, assigned_date)` 기준 loop 확보
2. 확보한 loop id를 `story_loop_id`로 사용

### 3.3 기존 질문 row도 lazy self-heal 해야 한다

질문 row가 이미 존재하더라도 `story_loop_id is null`일 수 있다.

이 경우 helper는 return 전에 반드시:

1. 대응 loop를 생성 또는 조회하고
2. 해당 질문 row의 `story_loop_id`를 채운 뒤
3. 채워진 row를 반환해야 한다

### 3.4 브리지 단계에서는 story card를 도입하지 않는다

이번 단계는 아직 스토리 카드 write 단계가 아니다.

따라서 이 단계에서 생성되는 loop는 질문 중심 브리지 loop다.

상태 원칙:

- 질문이 이미 존재하는 흐름이므로 loop 상태는 `question_generated`

---

## 4. 설계 방안

## 4.1 질문용 loop 확보 helper를 추가한다

권장 함수:

- `private.get_or_create_question_generated_story_loop(target_couple_id uuid, target_couple_date date, target_created_at timestamptz)`

이 helper의 역할은 아래와 같다.

1. `(couple_id, couple_date)` 기준 existing loop 조회
2. 없으면 `daily_story_loops` row 생성
3. 있으면 그대로 반환
4. 있는데 `status = 'waiting_partner_card'`면 질문이 생성된 흐름으로 승격

이 helper를 두는 이유:

1. 기존 질문 브리지와 이후 write RPC가 같은 loop 확보 책임을 공유하게 된다.
2. `daily_story_loops` upsert 규칙을 한 곳에 모을 수 있다.
3. 질문 생성 흐름의 상태 승격 규칙을 분산시키지 않을 수 있다.

## 4.2 `private.get_or_assign_daily_question_for_couple()`를 교체한다

수정 후 흐름은 아래와 같다.

1. `requested_couple_id`, `requested_target_date` 검증 유지
2. active couple / relationship date / target date validation 유지
3. 기존 advisory lock 유지
4. 해당 날짜 `daily_questions` row 조회
5. 찾았으면:
   - `story_loop_id`가 null인지 확인
   - null이면 질문용 loop 확보 helper 호출
   - 해당 질문 row 업데이트
   - 업데이트된 row 반환
6. 못 찾았으면:
   - 기존 질문 선택 로직 수행
   - 질문용 loop 확보 helper 호출
   - `story_loop_id`를 채운 상태로 `daily_questions` insert
   - insert 후 row 반환
7. 반환 직전 `story_loop_id`가 여전히 null이면 예외로 막는다

## 4.3 `private.get_or_assign_today_daily_question()`는 thin wrapper로 유지한다

이 함수는 재구현하지 않고 아래 역할만 유지한다.

1. `private.get_active_couple_for_current_user()`로 활성 커플 확보
2. `private.current_date_in_timezone(active_couple.timezone)`로 오늘 날짜 계산
3. `private.get_or_assign_daily_question_for_couple(active_couple.id, today)` 호출

이 정책이 필요한 이유는 다음과 같다.

1. 최신 구조에서 이미 사용자 경로와 service role 경로가 같은 private helper로 수렴하고 있다.
2. 여기서 today helper를 다시 monolithic helper로 되돌리면 호출 경로가 다시 분기된다.
3. 커플 timezone 기준 오늘 날짜 계산 규칙도 wrapper 쪽에 그대로 남겨야 한다.

## 4.4 timestamp 정책

브리지 단계에서 새로 만드는 loop의 시간값은 아래 원칙을 따른다.

1. `question_generated_at = target_created_at`
2. `story_edit_locked_at = target_created_at`
3. `created_at = target_created_at`
4. `updated_at = target_created_at`

여기서 `target_created_at`은:

1. 기존 질문 row를 self-heal 하는 경우 `daily_questions.created_at`
2. 새 질문 row를 만드는 경우 `now()`

이 규칙이 필요한 이유는 질문 브리지 loop가 "질문이 이미 생긴 상태"를 표현하기 때문이다.

---

## 5. SQL 초안 방향

권장 순서:

1. 질문용 loop helper `create or replace function`
2. `private.get_or_assign_daily_question_for_couple()` `create or replace function`

권장 초안:

```sql
create or replace function private.get_or_create_question_generated_story_loop(
  target_couple_id uuid,
  target_couple_date date,
  target_created_at timestamptz
)
returns public.daily_story_loops
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_loop public.daily_story_loops%rowtype;
begin
  select *
  into target_loop
  from public.daily_story_loops
  where couple_id = target_couple_id
    and couple_date = target_couple_date
  limit 1;

  if found then
    if target_loop.status = 'waiting_partner_card' then
      update public.daily_story_loops
      set
        status = 'question_generated',
        question_generated_at = coalesce(question_generated_at, target_created_at),
        story_edit_locked_at = coalesce(story_edit_locked_at, target_created_at)
      where id = target_loop.id
      returning * into target_loop;
    end if;

    return target_loop;
  end if;

  insert into public.daily_story_loops (
    couple_id,
    couple_date,
    status,
    question_generated_at,
    story_edit_locked_at,
    created_at,
    updated_at
  )
  values (
    target_couple_id,
    target_couple_date,
    'question_generated',
    target_created_at,
    target_created_at,
    target_created_at,
    target_created_at
  )
  on conflict on constraint daily_story_loops_couple_date_unique do nothing;

  select *
  into target_loop
  from public.daily_story_loops
  where couple_id = target_couple_id
    and couple_date = target_couple_date
  limit 1;

  if not found then
    raise exception 'question_generated_story_loop_bridge_failed';
  end if;

  return target_loop;
end;
$$;
```

그리고 실제 생성 원천 helper를 아래 방향으로 교체한다.

```sql
create or replace function private.get_or_assign_daily_question_for_couple(
  requested_couple_id uuid,
  requested_target_date date
)
returns public.daily_questions
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_couple public.couples%rowtype;
  target_daily_question public.daily_questions%rowtype;
  target_story_loop public.daily_story_loops%rowtype;
  assignment_count integer;
  active_question_count integer;
  selected_question_id uuid;
begin
  ...

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = requested_target_date
  limit 1;

  if found then
    if target_daily_question.story_loop_id is null then
      target_story_loop := private.get_or_create_question_generated_story_loop(
        target_daily_question.couple_id,
        target_daily_question.assigned_date,
        target_daily_question.created_at
      );

      update public.daily_questions as dq
      set story_loop_id = target_story_loop.id
      where dq.id = target_daily_question.id
      returning dq.* into target_daily_question;
    end if;

    if target_daily_question.story_loop_id is null then
      raise exception 'question_story_loop_bridge_failed';
    end if;

    return target_daily_question;
  end if;

  ...

  target_story_loop := private.get_or_create_question_generated_story_loop(
    target_couple.id,
    requested_target_date,
    now()
  );

  insert into public.daily_questions (
    couple_id,
    question_id,
    assigned_date,
    story_loop_id
  )
  values (
    target_couple.id,
    selected_question_id,
    requested_target_date,
    target_story_loop.id
  )
  on conflict on constraint daily_questions_couple_date_unique do nothing;

  select dq.*
  into target_daily_question
  from public.daily_questions as dq
  where dq.couple_id = target_couple.id
    and dq.assigned_date = requested_target_date
  limit 1;

  if not found then
    perform private.raise_app_error('question_assignment_failed');
  end if;

  if target_daily_question.story_loop_id is null then
    raise exception 'question_story_loop_bridge_failed';
  end if;

  return target_daily_question;
end;
$$;
```

## 5.1 명시적으로 건드리지 않는 함수

이번 단계에서는 아래 함수는 직접 수정하지 않는다.

1. `private.get_or_assign_today_daily_question()`
2. `public.get_or_assign_daily_question_for_couple(...)`
3. `public.get_or_assign_today_question()`
4. `public.get_today_question_answer_state()`
5. `public.submit_today_question_answer(text)`

이 함수들은 기존 시그니처와 호출 구조를 유지한 채, 내부에서 브리지화된 private helper를 자동으로 타게 된다.

---

## 6. 이 단계가 끝난 뒤 보장되는 것

4단계가 끝나면 아래가 보장되어야 한다.

1. 기존 앱 경로로 새로 생기는 오늘 질문 row는 null `story_loop_id`를 만들지 않는다.
2. service role 경로로 새로 생기는 질문 row도 null `story_loop_id`를 만들지 않는다.
3. 이미 존재하던 null row도 helper 진입 시 복구된다.
4. 따라서 5단계 backfill은 "과거에 이미 남아 있는 null row"만 대상으로 다루면 된다.

즉 backfill의 입력 집합이 닫힌다.

---

## 7. 다음 단계와의 연결

### 7.1 5단계 backfill

이제 5단계는 과거 row만 메우면 된다.

### 7.2 6단계 제약 강화

4단계와 5단계가 끝난 뒤에야 아래 제약을 안전하게 걸 수 있다.

1. `daily_questions.story_loop_id set not null`
2. `unique (story_loop_id)`

---

## 8. 최종 결론

4단계의 본질은 기존 질문 구조를 유지한 채, 실제 최신 생성 원천 helper에 새 루프 연결을 강제하는 것이다.

이 단계가 먼저 들어가야만,

1. backfill이 재오염되지 않고
2. service role 경로까지 포함해 null `story_loop_id` 재발을 막고
3. 제약 강화를 운영 중 경로와 충돌 없이 진행할 수 있다.
