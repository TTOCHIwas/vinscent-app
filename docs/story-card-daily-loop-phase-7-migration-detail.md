# 스토리 카드 루프 7단계 read RPC 상세 설계

작성일: 2026-07-06

본 문서는 7단계 read RPC 추가 범위를 실제 현재 코드 기준으로 고정한다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-contract-design.md`
- `docs/story-card-daily-loop-physical-schema-design.md`
- `docs/story-card-daily-loop-migration-phase-design.md`

관련 현재 코드:

- `apps/mobile/lib/features/home/presentation/home_screen.dart`
- `apps/mobile/lib/features/questions/application/question_detail_provider.dart`
- `apps/mobile/lib/features/questions/data/daily_question_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_answer_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_history_repository.dart`
- `supabase/migrations/20260601001000_create_daily_question_history_rpc.sql`
- `supabase/migrations/20260601000000_reveal_completed_daily_question_answers.sql`

## 1. 현재 read 경로의 근원지

현재 질문 read는 세 갈래로 분산돼 있다.

1. 홈의 오늘 질문
   - `get_or_assign_today_question()`
2. 오늘 답변 상태
   - `get_today_question_answer_state()`
3. 과거 날짜 질문 상세
   - `get_daily_question_answer_state_for_date(target_date)`

이 구조의 문제는 다음과 같다.

- 홈은 질문과 답변 상태를 서로 다른 RPC로 읽은 뒤 Flutter에서 합성한다.
- 날짜 상세는 오늘과 과거 날짜를 서로 다른 provider와 RPC 경로로 분기한다.
- 월간 캘린더는 날짜 단위 story card 요약 계약이 아직 없다.
- 새 구조에서는 질문이 하루 공용 루프의 하위 단계이므로, 질문 중심 read를 그대로 홈의 최상위 진입점으로 둘 수 없다.

따라서 7단계의 목적은 기존 질문 RPC를 제거하는 것이 아니라, story loop 기준 read aggregate를 먼저 추가하는 것이다.

## 2. 7단계에서 추가할 public read RPC

### 2.1 `public.get_today_story_loop_summary()`

홈 화면 전용 today summary read다.

책임:

- 현재 커플의 `current_couple_date` 기준 하루 공용 루프 상태를 1행으로 반환
- 카드 0..2장 요약
- 생성된 질문의 최소 요약
- 답변 진행 여부 요약
- 홈이 다음 행동을 결정할 수 있는 최소 boolean 반환

반환 계약 핵심:

- `couple_id`
- `couple_date`
- `access_mode`
- `loop_id`
- `loop_status`
- `story_edit_locked`
- `card_count`
- `can_edit_story`
- `can_answer_question`
- `first_card_*`
- `second_card_*`
- `daily_question_id`
- `question_*`
- `question_status`
- `my_answer_exists`
- `partner_answer_exists`
- `answer_count`

설계 규칙:

- readable couple이 있으면 항상 1행을 반환한다.
- 오늘 루프가 없으면 `loop_id` 이하 aggregate 필드는 `null` 또는 `0/false`다.
- read에서 루프나 질문을 생성하지 않는다.

### 2.2 `public.get_story_loop_detail(target_date date)`

특정 날짜의 상세 aggregate read다.

책임:

- 날짜 단위 카드 0..2장
- 생성된 질문 0..1개
- 답변 상태
- 편집 가능 여부 / 답변 가능 여부
- archived read-only 포함 접근 모드 반영

반환 계약 핵심:

- `couple_id`
- `couple_date`
- `access_mode`
- `loop_id`
- `loop_status`
- `story_edit_locked`
- `can_edit_story`
- `can_answer_question`
- `card_count`
- `first_card_*`
- `second_card_*`
- `daily_question_id`
- `question_*`
- `question_status`
- `my_answer_*`
- `partner_answer_*`
- `answer_count`

설계 규칙:

- `target_date`가 `relationship_start_date` 이전이거나 `current_couple_date` 이후면 0행 반환
- 날짜가 유효하면 항상 1행 반환
- 유효하지만 루프/질문이 없으면 empty aggregate 1행 반환
- read에서 루프나 질문을 생성하지 않는다.

### 2.3 `public.get_story_loop_month_summary(target_month date)`

월간 캘린더 grid 전용 read다.

책임:

- 해당 월의 날짜별 카드 stack 요약만 반환
- 1일 1행 flat row transport 제공

반환 계약 핵심:

- `couple_date`
- `loop_status`
- `card_count`
- `first_card_*`
- `second_card_*`

설계 규칙:

- 카드가 1장 이상 있는 날짜만 반환
- 질문 본문, 답변 본문, scene payload는 포함하지 않는다.
- 카드 정렬 기준은 `submitted_at asc, id asc`

## 3. 기존 caller와의 연결

### 3.1 홈

현재:

- `HomeScreen`
- `questionDetailProvider(null)`
- `todayQuestionControllerProvider`
- `todayAnswerControllerProvider`

7단계 이후 목표:

- 홈은 `get_today_story_loop_summary()`만 읽는 전용 provider로 갈아탄다.
- 질문 화면 이동 여부는 summary의 질문/답변 요약 필드로 결정한다.

### 3.2 날짜 상세

현재:

- 오늘 날짜: `todayQuestionControllerProvider + todayAnswerControllerProvider`
- 과거 날짜: `dailyQuestionHistoryProvider`

7단계 이후 목표:

- 오늘/과거 분기 없이 `get_story_loop_detail(target_date)` 단일 aggregate로 통합한다.

### 3.3 월간 캘린더

현재:

- grid 자체는 날짜 숫자만 렌더링
- 상세를 누르면 history RPC fan-out

7단계 이후 목표:

- grid는 `get_story_loop_month_summary(target_month)`만 읽는다.
- 셀의 카드 시각 표현은 month summary로 결정한다.

## 4. 구현 경계

7단계에서는 아래만 한다.

- 새 public read RPC 3개 추가

7단계에서는 아직 아래를 하지 않는다.

- Flutter provider 교체
- 질문 write 경계 수정
- story card write RPC 추가
- 알림 helper 추가

즉 7단계는 read contract를 먼저 잠그는 단계다.

## 5. 구현 원칙

1. 기존 질문 RPC는 보존한다.
2. 새 read RPC는 pure read여야 한다.
3. `private.get_current_couple_context()`를 사용해 `access_mode`, `current_couple_date`를 맞춘다.
4. partner answer 공개 규칙은 기존 `private.get_today_question_answer_state(...)`를 재사용해 유지한다.
5. month summary는 flat row transport를 사용하고, today/detail은 single-row aggregate transport를 사용한다.
