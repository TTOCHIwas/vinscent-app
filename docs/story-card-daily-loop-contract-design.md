# 스토리 카드 루프 read 모델 계약 설계

작성일: 2026-07-06

이 문서는 2단계 caller 전환에 앞서 `features/story_loops` read 계층의 Dart 타입 계약을 실제 코드와 실제 RPC 시그니처 기준으로 잠그기 위한 문서다.

기준 파일:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-caller-transition-design.md`
- `supabase/migrations/20260706000000_create_daily_story_loops.sql`
- `supabase/migrations/20260706006000_create_story_loop_read_rpcs.sql`
- `apps/mobile/lib/features/questions/data/daily_question.dart`
- `apps/mobile/lib/features/questions/data/daily_question_answer_state.dart`
- `apps/mobile/lib/features/questions/data/question_detail_state.dart`
- `apps/mobile/lib/features/questions/data/daily_question_history_entry.dart`
- `apps/mobile/lib/features/questions/data/daily_question_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_answer_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_history_repository.dart`
- `apps/mobile/lib/features/questions/application/question_detail_provider.dart`
- `apps/mobile/lib/features/couple/data/couple.dart`

## 1. 이번 문서의 범위

이번 문서에서 잠그는 것은 다음 네 가지다.

1. `features/story_loops/data`에 들어갈 read 모델 타입
2. 기존 질문 모델 중 재사용할 것과 새로 만들 것을 구분하는 기준
3. RPC row를 Dart 모델로 변환하는 repository 경계
4. provider가 `empty`와 `unavailable`을 어떻게 나누는지에 대한 해석 규칙

이번 문서에서 아직 잠그지 않는 것은 다음과 같다.

- story card write RPC
- story card 편집 payload 저장 구조
- 홈/캘린더 위젯 구현 코드
- 질문 답변 write 교체

## 2. 현재 질문 read 구조 추적

현재 질문 read 흐름은 세 갈래다.

### 2.1 오늘 질문

caller:

1. `questionDetailProvider(null)`
2. `todayQuestionControllerProvider`
3. `DailyQuestionRepository.fetchTodayQuestion()`
4. RPC `get_or_assign_today_question()`

실제 반환 모델:

- `DailyQuestion`

### 2.2 오늘 답변 상태

caller:

1. `questionDetailProvider(null)`
2. `todayAnswerControllerProvider`
3. `DailyQuestionAnswerRepository.fetchTodayAnswerState()`
4. RPC `get_today_question_answer_state()`

실제 반환 모델:

- `DailyQuestionAnswerState`

### 2.3 과거 날짜 상세

caller:

1. `questionDetailProvider(targetDate)`
2. `dailyQuestionHistoryProvider(targetDate)`
3. `DailyQuestionHistoryRepository.fetchByDate(date)`
4. RPC `get_daily_question_answer_state_for_date(target_date)`

실제 반환 모델:

- `DailyQuestionHistoryEntry`
  - `DailyQuestion`
  - `DailyQuestionAnswerState`

근원 문제는 질문 leaf 모델과 상위 날짜 aggregate가 뒤섞여 있다는 점이다. 현재 `QuestionDetailState`는 질문이 화면의 루트였기 때문에 성립했지만, 새 구조에서는 날짜 루트 안에 카드와 질문이 함께 있어야 하므로 그대로 재사용할 수 없다.

## 3. 재사용 자산과 폐기 대상

### 3.1 그대로 재사용하는 타입

아래 타입은 새 read 계층에서도 그대로 재사용한다.

#### `CoupleAccessMode`

출처:

- `apps/mobile/lib/features/couple/data/couple.dart`

재사용 이유:

- 새 RPC들도 `access_mode`를 그대로 반환한다.
- archived read-only 판단은 이미 이 enum이 권위를 가지고 있다.

#### `QuestionSource`
#### `DailyQuestionStatus`
#### `DailyQuestion`

출처:

- `apps/mobile/lib/features/questions/data/daily_question.dart`

재사용 이유:

- 새 상세 RPC도 결국 질문 leaf는 기존 질문 개념을 그대로 사용한다.
- `question_source`, `question_category`, `question_mood`, `question_status`는 기존 질문 UI가 그대로 소비하는 값이다.

주의:

- story loop RPC row는 `assigned_date` 대신 `couple_date`, `status` 대신 `question_status`를 준다.
- 따라서 repository가 row adapter를 통해 `DailyQuestion.fromJson` 입력 형식으로 먼저 정규화해야 한다.

#### `DailyQuestionAnswerState`

출처:

- `apps/mobile/lib/features/questions/data/daily_question_answer_state.dart`

재사용 이유:

- 상세 RPC는 `my_answer_*`, `partner_answer_*`, `answer_count`를 모두 내려준다.
- 기존 질문 상세 UI가 이미 이 타입에 맞춰져 있다.

주의:

- story loop 상세 RPC도 `status` 컬럼명이 아니라 `question_status`를 반환한다.
- repository에서 `question_status -> status`로 정규화한 뒤 `DailyQuestionAnswerState.fromJson`에 넘겨야 한다.

### 3.2 재사용하지 않는 타입

#### `QuestionDetailState`

재사용하지 않는 이유:

- 새 상세 루트는 질문이 아니라 날짜 aggregate다.
- 카드 `0..2장`, 카드 수정 가능 여부, 루프 상태를 담을 수 없다.

#### `DailyQuestionHistoryEntry`

재사용하지 않는 이유:

- 이 타입은 질문-first aggregate다.
- 새 상세 aggregate는 질문이 없고 카드만 있는 날짜도 정상 상태로 다뤄야 한다.

## 4. 새 read 타입 계약

## 4.1 루프 상태 enum

`daily_story_loops.status`는 migration `20260706000000_create_daily_story_loops.sql` 기준으로 아래 네 값만 허용된다.

```dart
enum StoryLoopStatus {
  waitingPartnerCard,
  questionGenerated,
  answeredByOne,
  completed;

  factory StoryLoopStatus.fromJson(String value) {
    return switch (value) {
      'waiting_partner_card' => StoryLoopStatus.waitingPartnerCard,
      'question_generated' => StoryLoopStatus.questionGenerated,
      'answered_by_one' => StoryLoopStatus.answeredByOne,
      'completed' => StoryLoopStatus.completed,
      _ => throw FormatException('Unknown story loop status: $value'),
    };
  }
}
```

중요 규칙:

- `empty`는 persisted status가 아니다.
- `empty`는 루프 row 부재 또는 카드/질문 부재를 provider가 해석한 화면 상태다.

## 4.2 카드 preview 모델

홈 summary와 월간 summary는 카드의 미리보기 정보만 필요하다.

```dart
class StoryLoopCardPreview {
  const StoryLoopCardPreview({
    required this.id,
    required this.authorUserId,
    required this.previewPath,
    required this.submittedAt,
  });

  final String id;
  final String authorUserId;
  final String previewPath;
  final DateTime submittedAt;
}
```

이 타입이 담당하는 RPC:

- `get_today_story_loop_summary()`
- `get_story_loop_month_summary(target_month)`

## 4.3 카드 detail 모델

상세 화면은 preview 외에 scene path와 content flag를 함께 알아야 한다.

```dart
class StoryLoopCardDetail {
  const StoryLoopCardDetail({
    required this.id,
    required this.authorUserId,
    required this.previewPath,
    required this.sceneDataPath,
    required this.hasPhoto,
    required this.hasDrawing,
    required this.hasText,
    required this.submittedAt,
    required this.revision,
  });

  final String id;
  final String authorUserId;
  final String previewPath;
  final String sceneDataPath;
  final bool hasPhoto;
  final bool hasDrawing;
  final bool hasText;
  final DateTime submittedAt;
  final int revision;
}
```

이 타입이 담당하는 RPC:

- `get_story_loop_detail(target_date)`

## 4.4 질문 summary 모델

오늘 홈 summary는 질문 leaf 전체가 아니라 홈 CTA 판단에 필요한 최소 질문 정보만 가진다.

```dart
class StoryLoopQuestionSummary {
  const StoryLoopQuestionSummary({
    required this.question,
    required this.myAnswerExists,
    required this.partnerAnswerExists,
    required this.answerCount,
  });

  final DailyQuestion question;
  final bool myAnswerExists;
  final bool partnerAnswerExists;
  final int answerCount;
}
```

분리 이유:

- `get_today_story_loop_summary()`는 `my_answer_id`, `my_answer_text`를 주지 않는다.
- 따라서 홈 summary에 `DailyQuestionAnswerState`를 바로 재사용하면 가짜 nullable 필드가 늘어난다.

## 4.5 질문 detail 모델

상세 날짜는 질문 leaf와 답변 상태를 모두 가져야 한다.

```dart
class StoryLoopQuestionDetail {
  const StoryLoopQuestionDetail({
    required this.question,
    required this.answerState,
  });

  final DailyQuestion question;
  final DailyQuestionAnswerState answerState;
}
```

이 타입이 담당하는 RPC:

- `get_story_loop_detail(target_date)`

## 4.6 오늘 summary aggregate

```dart
class TodayStoryLoopSummary {
  const TodayStoryLoopSummary({
    required this.coupleId,
    required this.coupleDate,
    required this.accessMode,
    required this.storyEditLocked,
    required this.canEditStory,
    required this.canAnswerQuestion,
    required this.cardCount,
    required this.cards,
    this.loopId,
    this.loopStatus,
    this.question,
  });

  final String coupleId;
  final DateTime coupleDate;
  final CoupleAccessMode accessMode;
  final String? loopId;
  final StoryLoopStatus? loopStatus;
  final bool storyEditLocked;
  final bool canEditStory;
  final bool canAnswerQuestion;
  final int cardCount;
  final List<StoryLoopCardPreview> cards;
  final StoryLoopQuestionSummary? question;
}
```

중요 규칙:

- `loopId == null`은 오늘 날짜에 아직 루프 row가 생성되지 않은 정상 상태다.
- `cards.length`는 항상 `0..2`
- `question != null`이면 질문 leaf가 생성된 상태다.

## 4.7 날짜 detail aggregate

```dart
class StoryLoopDetail {
  const StoryLoopDetail({
    required this.coupleId,
    required this.coupleDate,
    required this.accessMode,
    required this.storyEditLocked,
    required this.canEditStory,
    required this.canAnswerQuestion,
    required this.cardCount,
    required this.cards,
    this.loopId,
    this.loopStatus,
    this.question,
  });

  final String coupleId;
  final DateTime coupleDate;
  final CoupleAccessMode accessMode;
  final String? loopId;
  final StoryLoopStatus? loopStatus;
  final bool storyEditLocked;
  final bool canEditStory;
  final bool canAnswerQuestion;
  final int cardCount;
  final List<StoryLoopCardDetail> cards;
  final StoryLoopQuestionDetail? question;
}
```

중요 규칙:

- 카드만 있고 질문이 없는 날짜를 표현해야 하므로 `question`은 nullable이다.
- 질문이 존재하면 `answerState`는 항상 함께 붙는다.

## 4.8 월간 summary row 모델

```dart
class StoryLoopMonthSummaryDay {
  const StoryLoopMonthSummaryDay({
    required this.coupleDate,
    required this.loopStatus,
    required this.cardCount,
    required this.cards,
  });

  final DateTime coupleDate;
  final StoryLoopStatus loopStatus;
  final int cardCount;
  final List<StoryLoopCardPreview> cards;
}
```

중요 규칙:

- month summary RPC는 카드가 1장 이상 있는 날짜만 반환한다.
- 따라서 이 모델은 `empty` 날짜를 표현하지 않는다.

## 5. repository 계약

권장 위치:

- `apps/mobile/lib/features/story_loops/data/story_loop_read_repository.dart`

권장 인터페이스:

```dart
abstract interface class StoryLoopReadRepository {
  Future<TodayStoryLoopSummary?> fetchTodaySummary();

  Future<StoryLoopDetail?> fetchDetail(DateTime date);

  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(DateTime month);
}
```

반환 규칙:

- `fetchTodaySummary()`
  - RPC 응답이 empty set이면 `null`
  - row가 있으면 `TodayStoryLoopSummary`
- `fetchDetail(date)`
  - RPC 응답이 empty set이면 `null`
  - row가 있으면 `StoryLoopDetail`
- `fetchMonthSummary(month)`
  - empty list 허용

이 계약을 택하는 이유:

- phase 7 RPC는 invalid range일 때 empty set을 반환한다.
- provider가 couple/date 유효성 검사를 먼저 하고, repository는 transport 결과만 보존하는 편이 현재 구조와 잘 맞는다.

## 6. RPC row 정규화 규칙

story loop RPC는 기존 질문 모델과 컬럼명이 다르다. 따라서 repository 안에서 row adapter를 먼저 거쳐야 한다.

## 6.1 `DailyQuestion` adapter

입력 source:

- `get_today_story_loop_summary()`
- `get_story_loop_detail(target_date)`

정규화 규칙:

```dart
Map<String, dynamic> _toDailyQuestionJson(
  Map<String, dynamic> row,
) {
  return {
    'daily_question_id': row['daily_question_id'],
    'couple_id': row['couple_id'],
    'question_id': row['question_id'],
    'question_text': row['question_text'],
    'question_source': row['question_source'],
    'question_category': row['question_category'],
    'question_mood': row['question_mood'],
    'assigned_date': row['couple_date'],
    'status': row['question_status'],
  };
}
```

이유:

- `DailyQuestion.fromJson`이 기대하는 key와 story loop RPC key가 다르다.

## 6.2 `DailyQuestionAnswerState` adapter

입력 source:

- `get_story_loop_detail(target_date)`

정규화 규칙:

```dart
Map<String, dynamic> _toAnswerStateJson(
  Map<String, dynamic> row,
) {
  return {
    'daily_question_id': row['daily_question_id'],
    'status': row['question_status'],
    'my_answer_id': row['my_answer_id'],
    'my_answer_text': row['my_answer_text'],
    'my_answer_answered_at': row['my_answer_answered_at'],
    'my_answer_updated_at': row['my_answer_updated_at'],
    'partner_answer_exists': row['partner_answer_exists'],
    'partner_answer_id': row['partner_answer_id'],
    'partner_answer_text': row['partner_answer_text'],
    'partner_answer_answered_at': row['partner_answer_answered_at'],
    'partner_answer_updated_at': row['partner_answer_updated_at'],
    'answer_count': row['answer_count'],
  };
}
```

## 6.3 카드 순서 복원 규칙

오늘 summary, detail, month summary는 모두 `first_card_*`, `second_card_*` flat row를 쓴다.

repository 규칙:

1. `first_card_id != null`이면 첫 번째 카드를 리스트에 넣는다.
2. `second_card_id != null`이면 두 번째 카드를 이어서 넣는다.
3. 리스트 순서는 항상 RPC 순서를 유지한다.

즉 presentation은 `cards[0]`, `cards[1]`의 순서를 그대로 믿고 사용하면 된다.

## 7. provider 해석 규칙

## 7.1 `storyLoopDetailProvider(date)`

현재 `questionDetailProvider`가 하던 날짜 유효성 검사는 유지한다.

검사 순서:

1. `coupleControllerProvider.future`
2. `canReadSharedData`
3. `relationshipStartDate`
4. `targetDate < relationshipStartDate`
5. `targetDate > currentDate`
6. 그 다음에만 `StoryLoopReadRepository.fetchDetail(date)`

이 규칙을 유지하는 이유:

- `get_story_loop_detail(target_date)`는 유효하지 않은 날짜에서 empty set을 반환한다.
- 하지만 화면은 `future`, `beforeRelationshipStartDate`, `unavailable`을 서로 다른 이유로 구분해야 한다.
- 이 구분은 현재도 provider가 하고 있으며, 새 구조에서도 caller에서 유지해야 한다.

## 7.2 `empty`와 `loaded` 구분

`StoryLoopDetail` row가 존재하더라도 아래 조건이면 화면 상태는 `empty`로 해석한다.

- `loopId == null`
- `cardCount == 0`
- `question == null`

그 외에는 `loaded`다.

즉 `empty`는 에러가 아니라 유효한 날짜의 정상 상태다.

## 7.3 `todayStoryLoopSummaryProvider`

홈 summary도 couple access 검사를 먼저 수행한다.

해석 규칙:

- 커플 자체가 없거나 읽기 불가면 summary 호출 이전에 상위 unavailable 상태
- repository row가 있고 `loopId == null && cardCount == 0 && question == null`이면 오늘 빈 상태
- 카드가 1장 이상이거나 질문이 존재하면 loaded 상태

## 8. 파일 배치 확정안

이번 계약 기준 `features/story_loops/data` 확정안은 아래다.

```text
apps/mobile/lib/features/story_loops/data/
  story_loop_status.dart
  story_loop_card_preview.dart
  story_loop_card_detail.dart
  story_loop_question_summary.dart
  story_loop_question_detail.dart
  today_story_loop_summary.dart
  story_loop_detail.dart
  story_loop_month_summary_day.dart
  story_loop_read_repository.dart
```

중요한 구조 원칙:

- 질문 leaf는 기존 `questions/data` 모델을 재사용한다.
- 날짜 aggregate는 `story_loops/data`가 소유한다.
- month summary는 질문 leaf를 직접 참조하지 않는다.

## 9. 최종 정리

이번 계약의 핵심은 새 타입을 많이 만드는 것이 아니라, 질문 leaf와 날짜 aggregate의 경계를 명확히 나누는 것이다.

정리하면 다음과 같다.

1. 질문 자체는 `DailyQuestion`, `DailyQuestionAnswerState`를 계속 쓴다.
2. 카드와 루프 상태는 `story_loops` 새 모델이 소유한다.
3. story loop RPC row는 repository에서 먼저 정규화한 뒤 기존 질문 leaf로 변환한다.
4. provider는 couple/date 유효성 검사를 계속 담당하고, repository는 transport 변환만 담당한다.
5. `empty`는 persisted status가 아니라 상위 aggregate 해석 결과다.

이 계약을 기준으로 다음 단계에서는 `features/story_loops` read repository와 provider 골격을 실제 코드로 내릴 수 있다.
