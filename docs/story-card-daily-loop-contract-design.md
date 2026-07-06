# 스토리 카드 일일 루프 계약 설계

작성일: 2026-07-06

이 문서는 `스토리 카드 작성 -> 질문 생성 -> 각자 답변` 구조로 전환하기 위한 1차 계약 설계를 정리한다.  
기준은 다음 두 문서다.

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`

본 문서는 구현 직전 계약 잠금 문서이며, 읽기 계약 3개와 write 경계 1개를 다룬다.

## 1. 전제

현재 코드베이스는 질문-first 구조다. 실제 호출 흐름은 다음 특징을 가진다.

- 질문 조회 read가 질문 assign write를 유발한다.
- 답변 상태 조회 read도 질문 assign write를 유발한다.
- 캘린더 월간 grid는 현재 기록 데이터를 읽지 않는다.
- 날짜 상세는 질문 history와 표현 summary를 화면단에서 fan-out 조합한다.

새 구조에서는 위 특성을 그대로 재사용하지 않는다.

핵심 전환 원칙:

1. 읽기 계약은 pure read여야 한다.
2. 질문 생성은 두 번째 카드 저장 write의 후행 결과여야 한다.
3. 홈 / 월간 / 상세는 서로 다른 읽기 모델로 분리한다.
4. 카드 / 질문 / 답변 상태 전이는 서버 write 경계 안에서 원자적으로 끝나야 한다.

## 2. `todayStoryLoopSummary` 계약

### 2.1 목적

`todayStoryLoopSummary`는 홈 화면 전용 읽기 모델이다.  
책임은 "오늘 하루 공용 루프를 홈에서 렌더링하고, 사용자의 다음 행동을 결정할 최소 정보 제공"까지다.

### 2.2 포함 범위

- 오늘 커플 날짜
- 오늘 루프 존재 여부
- 오늘 카드 `0..2장`
- 질문 생성 여부
- 질문 생성 후 최소 질문 요약
- 답변 진행 요약
- 홈 1차 액션 결정 정보
- active / archived read-only 구분

### 2.3 제외 범위

- 질문 상세 본문
- 답변 본문 텍스트
- 캘린더 월간 집계
- 위젯 fallback 미리보기
- 표현 / 녹음 상태
- 편집기 원본 scene / layer payload

### 2.4 상태 모델

```dart
sealed class TodayStoryLoopSummaryState {
  const TodayStoryLoopSummaryState({
    required this.coupleDate,
  });

  final DateTime coupleDate;
}

final class EmptyTodayStoryLoopSummaryState
    extends TodayStoryLoopSummaryState {
  const EmptyTodayStoryLoopSummaryState({
    required super.coupleDate,
  });
}

final class LoadedTodayStoryLoopSummaryState
    extends TodayStoryLoopSummaryState {
  const LoadedTodayStoryLoopSummaryState({
    required super.coupleDate,
    required this.loopId,
    required this.loopStatus,
    required this.storyEditLocked,
    required this.cards,
    required this.primaryAction,
    this.question,
  });

  final String loopId;
  final StoryLoopStatus loopStatus;
  final bool storyEditLocked;
  final List<StoryCardHomePreview> cards;
  final TodayStoryLoopPrimaryAction primaryAction;
  final StoryLoopQuestionHomePreview? question;
}
```

### 2.5 핵심 규칙

- 오늘 아무도 카드를 올리지 않은 상태는 오류가 아니라 정상 `empty` 상태다.
- read는 루프, 카드, 질문을 생성하지 않는다.
- 홈은 `questionDetailProvider`를 직접 보지 않고 이 summary만 소비한다.
- 라우트 문자열은 summary 계약에 넣지 않고, presentation에서 action enum을 route로 변환한다.

## 3. `storyLoopDetail` 계약

### 3.1 목적

`storyLoopDetail`은 특정 날짜의 하루 공용 루프 상세 aggregate다.  
기존 질문 상세와 캘린더 상세의 fan-out 구조를 날짜 단위 aggregate 하나로 수렴시킨다.

### 3.2 포함 범위

- 대상 날짜
- 해당 날짜 카드 `0..2장`
- 생성된 질문 `0..1개`
- 답변 상태
- 카드 수정/삭제 가능 여부
- 질문 답변 가능 여부
- active / archived read-only 구분

### 3.3 제외 범위

- 월간 grid 데이터
- 홈 CTA 상태
- 위젯 fallback 데이터
- 표현 요약
- 녹음 상태
- 편집기 원본 전체 payload

### 3.4 상태 모델

```dart
enum StoryLoopDetailUnavailableReason {
  invalidDate,
  unavailable,
  beforeRelationshipStartDate,
  futureDate,
}

sealed class StoryLoopDetailState {
  const StoryLoopDetailState({
    required this.targetDate,
  });

  final DateTime targetDate;
}

final class UnavailableStoryLoopDetailState extends StoryLoopDetailState {
  const UnavailableStoryLoopDetailState({
    required super.targetDate,
    required this.reason,
  });

  final StoryLoopDetailUnavailableReason reason;
}

final class EmptyStoryLoopDetailState extends StoryLoopDetailState {
  const EmptyStoryLoopDetailState({
    required super.targetDate,
    required this.accessMode,
    required this.canCreateOrEditStory,
  });

  final StoryLoopDetailAccessMode accessMode;
  final bool canCreateOrEditStory;
}

final class LoadedStoryLoopDetailState extends StoryLoopDetailState {
  const LoadedStoryLoopDetailState({
    required super.targetDate,
    required this.loopId,
    required this.accessMode,
    required this.loopStatus,
    required this.storyEditLocked,
    required this.cards,
    this.question,
  });

  final String loopId;
  final StoryLoopDetailAccessMode accessMode;
  final StoryLoopStatus loopStatus;
  final bool storyEditLocked;
  final List<StoryCardDetailItem> cards;
  final StoryLoopQuestionDetail? question;
}
```

### 3.5 핵심 규칙

- 날짜 자체가 유효하지 않으면 `unavailable`
- 날짜는 유효하지만 루프 콘텐츠가 없으면 `empty`
- 카드 또는 질문 중 하나라도 있으면 `loaded`
- 오늘/과거 분기를 위해 여러 provider를 조합하지 않고, 항상 날짜 aggregate 하나만 읽는다.

## 4. `storyLoopMonthSummary` RPC 계약

### 4.1 목적

월간 캘린더 grid는 날짜 셀에 무엇을 그릴지 결정하기 위한 month summary만 소비한다.  
단건 상세 RPC를 월별로 반복 호출하는 구조는 사용하지 않는다.

### 4.2 도메인 해석

- 날짜별 정렬된 카드 목록 `0..2장`
- 정렬 기준은 `submitted_at ASC`
- 1장이면 단독 카드
- 2장이면 뒤 카드 + 앞 카드 겹침

### 4.3 transport 원칙

- RPC는 1일 1행 flat row 형식을 사용한다.
- `first_card_*`, `second_card_*` 형태로 반환한다.
- Flutter repository 계층에서 ordered cards list로 복원한다.

### 4.4 RPC 시그니처 초안

```sql
create or replace function public.get_story_loop_month_summary(
  target_month date
)
returns table (
  couple_date date,
  loop_status text,
  card_count integer,

  first_card_id uuid,
  first_card_author_user_id uuid,
  first_card_preview_path text,
  first_card_submitted_at timestamptz,

  second_card_id uuid,
  second_card_author_user_id uuid,
  second_card_preview_path text,
  second_card_submitted_at timestamptz
)
```

### 4.5 필드 의미

- `couple_date`
  - 커플 timezone 기준 날짜
- `loop_status`
  - UI 압축 상태가 아니라 서버 canonical 상태
- `card_count`
  - 해당 날짜 카드 수
- `first_card_*`
  - 업로드 시간상 먼저 올라온 카드
- `second_card_*`
  - 업로드 시간상 나중 카드

### 4.6 추가 규칙

- 월간 grid는 카드가 1장 이상 존재하는 날짜만 응답 row로 받는다.
- `card_count = 0`인 날짜는 응답에서 제외한다.
- 질문 본문, 답변 본문, 편집기 원본 payload는 월간 RPC에 포함하지 않는다.
- `preview_path`는 홈 / 캘린더 / 위젯 공통 미리보기 결과물의 참조값이다.

## 5. 루프 / 카드 / 질문 생성 write 경계

### 5.1 최상위 원칙

1. 읽기 RPC는 pure read여야 한다.
2. 질문 생성은 카드 write의 후행 결과여야 한다.
3. 클라이언트는 `카드 저장 -> 재조회 -> 질문 생성 요청` orchestration을 수행하지 않는다.
4. 상태 전이는 서버 write 경계 안에서 원자적으로 끝나야 한다.

### 5.2 읽기 RPC 원칙

아래 read 계열은 모두 pure read로 고정한다.

- `get_today_story_loop_summary`
- `get_story_loop_detail`
- `get_story_loop_month_summary`

금지 사항:

- read에서 루프 생성
- read에서 카드 생성
- read에서 질문 생성

### 5.3 advisory lock 기준

루프 단위 핵심 lock key:

- `couple_id + couple_date`

예시:

```sql
perform pg_advisory_xact_lock(
  hashtext('story_loop'),
  hashtext(target_couple.id::text || ':' || target_date::text)
);
```

질문 답변 write는 질문 단위 lock을 별도로 사용할 수 있지만, 질문 생성 자체는 루프 lock 내부에서 끝나야 한다.

### 5.4 persisted canonical status

persisted canonical status는 아래 수준으로 고정한다.

- `waiting_partner_card`
- `question_generated`
- `answered_by_one`
- `completed`

추가 해석:

- `empty`는 persisted status가 아니라 row 부재를 read model이 해석한 상태다.
- `cards_completed`는 두 번째 카드 저장과 질문 생성이 같은 트랜잭션에서 끝나므로 별도 persisted 상태로 유지하지 않는다.

### 5.5 public write 경계

1차 구현에서 public write 경계는 아래처럼 잡는다.

- `upsert_today_story_card`
- `delete_today_story_card`
- 질문 생성 없는 답변 제출 버전의 `submit_today_question_answer`

#### `upsert_today_story_card`

책임:

1. 인증
2. active couple 조회
3. 서버 기준 `current_couple_date` 결정
4. `(couple_id, couple_date)` advisory lock 획득
5. 루프 조회, 없으면 생성
6. 내 카드 생성 또는 수정
7. 카드 수 재계산
8. 카드 수가 1장이면 `waiting_partner_card`
9. 카드 수가 2장이고 질문이 없으면 내부 질문 생성
10. 루프 상태를 `question_generated`로 전이
11. 카드 잠금 반영
12. 알림 이벤트 적재
13. 최신 read model 반환

#### `delete_today_story_card`

책임:

1. 인증
2. active couple 조회
3. 서버 기준 `current_couple_date` 결정
4. `(couple_id, couple_date)` advisory lock 획득
5. 내 카드 revision 검증
6. 질문 생성 이후면 삭제 차단
7. 카드 삭제
8. 남은 카드 수 재계산
9. 남은 카드가 1장이면 `waiting_partner_card`
10. 남은 카드가 0장이면 루프 row 제거

### 5.6 내부 질문 생성 helper

질문 pool 선택 로직은 기존 `daily_questions` 축의 helper를 재사용할 수 있다.  
다만 역할은 "read 시 assign"이 아니라 "두 번째 카드 저장 시 내부 assign"으로 바뀐다.

허용되는 재사용:

- curated 질문 선택 순서
- 질문 pool 순환 규칙
- couple/date unique insert 패턴

허용되지 않는 재사용:

- `get_or_assign_*` 계열 read 진입 assign 구조를 새 루프 read에 그대로 노출하는 것

### 5.7 답변 write 경계 수정

답변 write는 더 이상 질문 생성을 유발하면 안 된다.

새 답변 write 원칙:

1. 인증
2. active couple 조회
3. 서버 기준 `current_couple_date` 결정
4. 해당 날짜 루프 조회
5. 루프 상태가 `question_generated` 이상인지 검증
6. 연결된 질문이 없으면 실패
7. 질문 단위 lock 획득
8. 답변 upsert
9. 답변 수 재계산
10. `daily_questions.status` 갱신
11. 루프 상태를 `answered_by_one` / `completed`로 동기화

즉 답변 write는 루프 또는 질문을 생성하지 않는다.

### 5.8 알림 이벤트 적재

스토리 루프 write는 push 직접 발송이 아니라 이벤트 적재까지만 책임진다.

1차 범위의 새 이벤트:

- 상대 스토리 카드 업로드
- 질문 생성 완료

기존 답변 완료 알림은 `daily_question_answers` 축의 패턴을 이어서 사용한다.

핵심 규칙:

- write 함수 안에서 이벤트 row 적재
- Edge Function 직접 호출 금지
- 클라이언트에서 알림 발송 orchestration 금지

## 6. 최종 정리

현재 저장소는 질문-first 구조라서 read가 write를 유발한다.  
새 스토리 카드 루프 구조는 이를 허용하지 않고, 녹음 기능처럼 write 함수 하나가 상태 전이와 이벤트 적재를 끝내는 방향으로 재구성해야 한다.

1차 구현 방향은 아래 한 줄로 정리된다.

- 읽기는 루프를 해석만 하고, 쓰기는 루프 상태를 원자적으로 전이시킨다.
