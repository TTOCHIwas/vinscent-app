# 스토리 카드 일일 루프 마이그레이션 단계 설계

작성일: 2026-07-06

본 문서는 스토리 카드 기반 일일 루프를 기존 `daily_questions` 중심 구조 위에 안전하게 도입하기 위한 마이그레이션 단계 설계를 정리한다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-contract-design.md`
- `docs/story-card-daily-loop-physical-schema-design.md`

기준 마이그레이션:

- `supabase/migrations/20260531002000_create_daily_questions.sql`
- `supabase/migrations/20260531006000_create_daily_question_answers.sql`
- `supabase/migrations/20260601000000_reveal_completed_daily_question_answers.sql`
- `supabase/migrations/20260623001000_add_readable_access_and_couple_timezone_dates.sql`
- `supabase/migrations/20260629002000_add_storage_cleanup_requests.sql`
- `supabase/migrations/20260629003000_redirect_storage_deletes_to_cleanup_requests.sql`

---

## 1. 문서 목적

이번 전환은 단순 테이블 추가가 아니라 기존 질문 생성 경로가 살아 있는 상태에서 새 일일 루프 구조를 병행 도입하는 작업이다.

따라서 아래 순서를 반드시 지켜야 한다.

1. 새 루프 구조를 먼저 추가한다.
2. 기존 질문 row를 새 루프에 연결할 수 있게 한다.
3. 기존 질문 생성 경로가 더 이상 null `story_loop_id`를 만들지 못하게 막는다.
4. 그 다음에 과거 데이터를 backfill 한다.
5. 마지막으로 `not null`, `unique` 제약을 강제한다.

이번 검토에서 확인된 핵심 사실은 다음과 같다.

- 앱 사용자 경로는 `private.get_or_assign_today_daily_question()`를 호출한다.
- 그러나 실제 `daily_questions` row 생성의 최신 source of truth는 `private.get_or_assign_daily_question_for_couple(requested_couple_id, requested_target_date)`다.
- service role 경로 `public.get_or_assign_daily_question_for_couple(...)`도 같은 private helper를 호출한다.
- 따라서 4단계 브리지는 `today` wrapper를 재구현하는 방식이 아니라, 실제 생성 원천 helper를 브리지화해야 한다.

이 문제를 막지 않으면 backfill 완료 직후에도 5단계 제약 강화가 안전하지 않다.

---

## 2. 현재 구조 기준 제약

### 2.1 현재 live write caller

현재 질문 축에서 실제로 살아 있는 caller는 아래 네 갈래다.

1. `public.get_or_assign_today_question()`
2. `public.get_today_question_answer_state()`
3. `public.submit_today_question_answer(text)`
4. `public.get_or_assign_daily_question_for_couple(requested_couple_id, requested_target_date)`

앞의 세 경로는 사용자 today 경로이고, 마지막 경로는 service role 날짜 지정 경로다.

### 2.2 실제 row 생성 메서드

현재 구조에서 실제 `daily_questions` row 생성은 `private.get_or_assign_daily_question_for_couple()`에 수렴된다.

즉 이번 전환에서 null `story_loop_id` 재발을 막으려면,

- 각 public RPC를 따로 건드리는 것이 아니라
- 실제 생성 메서드인 `private.get_or_assign_daily_question_for_couple()`를 먼저 브리지화해야 한다.
- `private.get_or_assign_today_daily_question()`는 커플 timezone 기준 오늘 날짜를 계산해 그 helper에 위임하는 thin wrapper로 유지해야 한다.

### 2.3 4단계가 backfill이면 안 되는 이유

기존 안에서는 4단계가 backfill, 5단계가 제약 강화, 7단계가 write RPC 전환이었다.

이 순서는 현재 코드 기준으로 안전하지 않다.

이유는 다음과 같다.

1. 4단계 backfill은 실행 시점의 null row만 메운다.
2. 그러나 7단계 전까지 기존 helper는 새 null row를 계속 만들 수 있다.
3. 그러면 4단계 직후에도 다시 null row가 생길 수 있다.
4. 이 상태에서 5단계 `story_loop_id not null`과 `unique (story_loop_id)`를 걸면 운영 중 쓰기 경로와 충돌한다.

따라서 단계 순서를 바꿔야 한다.

---

## 3. 수정된 마이그레이션 순서

### 3.1 1단계: 기반 테이블과 버킷 추가

제안 파일:

- `20260706000000_create_daily_story_loops.sql`

포함 대상:

1. `public.daily_story_loops`
2. `public.story_loop_cards`
3. `public.story_loop_notification_events`
4. `story-cards` storage bucket
5. 기본 index, trigger, select policy

이 단계에서는 기존 질문 write/read 경로를 건드리지 않는다.

### 3.2 2단계: storage cleanup 제약 확장

제안 파일:

- `20260706001000_expand_storage_cleanup_for_story_cards.sql`

포함 대상:

1. `storage_cleanup_requests.bucket_id` check 확장
2. `storage_cleanup_requests.cleanup_reason` check 확장

### 3.3 3단계: `daily_questions` 연결 컬럼 추가

제안 파일:

- `20260706002000_link_daily_questions_to_story_loops.sql`

포함 대상:

1. `daily_questions.story_loop_id uuid null`
2. `daily_story_loops_reference_unique`
3. `(couple_id, assigned_date, story_loop_id)` -> `(couple_id, couple_date, id)` 복합 FK
4. `story_loop_id` partial index

이 단계까지는 아직 기존 helper가 null row를 만들 수 있다.

### 3.4 4단계: 기존 질문 write 경로 브리지

제안 파일:

- `20260706003000_bridge_legacy_daily_question_writes_to_story_loops.sql`

포함 대상:

1. 질문 생성용 `daily_story_loops` upsert helper 추가
2. `private.get_or_assign_daily_question_for_couple()` 교체
3. `private.get_or_assign_today_daily_question()`는 기존 thin wrapper 구조 유지

핵심 목표:

- 4단계 이후 새로 만들어지는 `daily_questions` row는 반드시 유효한 `story_loop_id`를 가진다.
- 오늘 이미 존재하는 `daily_questions` row가 null `story_loop_id`여도 helper 진입 시 즉시 self-heal 한다.
- service role 질문 생성 경로도 같은 브리지를 타므로 스케줄 알림 경로에서도 null `story_loop_id`가 재발하지 않는다.

즉 4단계는 backfill 단계가 아니라 live write 차단 단계다.

### 3.5 5단계: 과거 null row backfill

제안 파일:

- `20260706004000_backfill_story_loops_from_daily_questions.sql`

포함 대상:

1. `story_loop_id is null`인 기존 `daily_questions` 기준 historical loop 생성
2. `daily_questions.story_loop_id` 업데이트
3. cardless bridge / historical loop 상태 정규화
4. 최종 null 및 상태 정규화 검증

이 단계가 4단계 뒤로 밀려야 하는 이유는,

- 이 시점부터는 기존 앱 경로가 더 이상 새 null row를 만들지 않기 때문이다.

### 3.6 6단계: 제약 강화

제안 파일:

- `20260706005000_finalize_daily_question_story_loop_constraints.sql`

포함 대상:

1. `daily_questions.story_loop_id set not null`
2. `daily_questions_story_loop_unique`

전제 조건:

- 4단계 브리지 반영 완료
- 5단계 backfill 완료
- null row 재발 경로 제거 확인

### 3.7 7단계: read RPC 추가

제안 파일:

- `20260706006000_create_story_loop_read_rpcs.sql`

포함 대상:

1. `public.get_today_story_loop_summary()`
2. `public.get_story_loop_detail(target_date date)`
3. `public.get_story_loop_month_summary(target_month date)`

### 3.8 8단계: write RPC 전환

제안 파일:

- `20260706007000_create_story_loop_write_rpcs.sql`

포함 대상:

1. `public.upsert_today_story_card(...)`
2. `public.delete_today_story_card(...)`
3. `public.submit_today_question_answer(text)` 수정

이 단계 이후부터 질문 생성의 authoritative write 주체가 스토리 카드 루프로 넘어간다.

### 3.9 9단계: archive purge 확장

제안 파일:

- `20260706008000_add_story_card_archive_cleanup.sql`

### 3.10 10단계: notification helper 확장

제안 파일:

- `20260706009000_add_story_loop_notification_helpers.sql`

---

## 4. 4단계 브리지의 요구사항

4단계는 반드시 아래를 만족해야 한다.

1. 기존 public 질문 RPC 시그니처는 유지한다.
2. service role 질문 RPC 시그니처는 유지한다.
3. 기존 질문 선택 알고리즘은 유지한다.
4. 기존 advisory lock 범위는 유지한다.
5. 기존 커플 timezone 기준 날짜 계산 규칙은 유지한다.
6. 기존 `daily_questions.status` 의미는 유지한다.
7. 단지 질문 row 생성 직전에 대응하는 `daily_story_loops`를 먼저 확보한다.
8. 오늘 이미 존재하는 질문 row가 null `story_loop_id`이면 return 전에 즉시 채운다.

즉 기존 기능은 보존하고, 루프 연결만 강제하는 브리지여야 한다.

---

## 5. 5단계 backfill의 요구사항

5단계는 아래 성질을 가져야 한다.

1. source 대상은 `story_loop_id is null`인 기존 `daily_questions` row다.
2. 날짜는 재계산하지 않고 `assigned_date`를 그대로 사용한다.
3. `(couple_id, assigned_date)` 기준으로 historical loop를 만든다.
4. 상태는 `daily_questions.status`를 그대로 신뢰해 매핑한다.
5. historical loop는 cardless loop다.
6. cardless bridge loop도 같은 상태 규칙으로 정규화한다.
7. 최종 검증은 이제 live path가 null row를 다시 만들지 않는다는 전제 위에서 수행한다.

---

## 6. 검증 순서

### 6.1 4단계 검증

1. 오늘 질문 조회
2. 오늘 질문 답변 상태 조회
3. 오늘 질문 답변 저장

위 세 경로를 호출한 뒤 아래를 확인한다.

1. 새 `daily_questions` row에 `story_loop_id`가 비어 있지 않다.
2. 연결된 `daily_story_loops` row가 존재한다.
3. 오늘 기존 질문 row가 null 이어도 재조회 후 채워진다.

### 6.2 5단계 검증

1. 기존 `story_loop_id is null` row가 모두 채워진다.
2. `(couple_id, assigned_date)` 기준 연결이 정확하다.
3. rerun 해도 중복 loop가 생기지 않는다.

### 6.3 6단계 검증

1. `story_loop_id` null insert/update가 차단된다.
2. 질문 한 건당 loop 연결이 1:1로 강제된다.
3. 3단계의 partial index는 최종 unique 제약 이후 제거된다.

---

## 7. 최종 결론

이번 검토로 확인된 수정 사항은 하나다.

- 4단계는 backfill이 아니라 브리지 단계여야 한다.

이 순서를 잠가야만,

1. 기존 질문 경로를 깨지 않고
2. null `story_loop_id` 재발을 막고
3. 그 뒤에 backfill과 제약 강화를 안전하게 진행할 수 있다.
