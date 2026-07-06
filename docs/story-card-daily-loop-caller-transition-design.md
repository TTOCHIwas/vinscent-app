# 스토리 카드 루프 caller 전환 설계

작성일: 2026-07-06

본 문서는 7단계 read RPC 적용 이후 홈, 질문 상세, 캘린더 화면의 상위 caller를 기존 질문 중심 경로에서 스토리 카드 루프 중심 경로로 전환하기 위한 설계를 정리한다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-current-structure-analysis.md`
- `docs/story-card-daily-loop-phase-7-migration-detail.md`

검토한 현재 코드:

- `apps/mobile/lib/features/home/presentation/home_screen.dart`
- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`
- `apps/mobile/lib/features/questions/presentation/today_question_answer_screen.dart`
- `apps/mobile/lib/features/questions/application/question_detail_provider.dart`
- `apps/mobile/lib/features/questions/application/question_detail_navigation_provider.dart`
- `apps/mobile/lib/features/questions/application/today_question_controller.dart`
- `apps/mobile/lib/features/questions/application/today_answer_controller.dart`
- `apps/mobile/lib/features/questions/application/daily_question_history_provider.dart`
- `apps/mobile/lib/features/questions/data/daily_question_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_answer_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_history_repository.dart`
- `apps/mobile/lib/app/router.dart`
- `apps/mobile/lib/features/shell/presentation/app_shell.dart`

## 1. 목적

이번 전환의 목적은 질문 화면을 없애는 것이 아니라, 홈과 상세와 캘린더의 상위 read caller가 더 이상 질문 provider를 직접 기준으로 삼지 않도록 바꾸는 것이다.

전환 이후의 고정 원칙은 다음과 같다.

1. 오늘 홈 상태는 `todayStoryLoopSummary`만 읽는다.
2. 특정 날짜 상세는 `storyLoopDetail(date)`만 읽는다.
3. 월간 캘린더는 `storyLoopMonthSummary(month)`만 읽는다.
4. 질문은 더 이상 상위 aggregate가 아니라 `storyLoopDetail` 안의 하위 leaf가 된다.

## 2. 현재 caller 추적

### 2.1 홈 화면

현재 호출 경로:

1. `HomeScreen`
2. `_QuestionCharacterPreview`
3. `questionDetailProvider(null)`
4. 내부 분기
   - 오늘이며 수정 가능: `todayQuestionControllerProvider` + `todayAnswerControllerProvider`
   - 과거 또는 읽기 전용: `dailyQuestionHistoryProvider(date)`

실제 read 메서드:

- `SupabaseDailyQuestionRepository.fetchTodayQuestion()`
  - RPC `get_or_assign_today_question()`
- `SupabaseDailyQuestionAnswerRepository.fetchTodayAnswerState()`
  - RPC `get_today_question_answer_state()`
- `SupabaseDailyQuestionHistoryRepository.fetchByDate(date)`
  - RPC `get_daily_question_answer_state_for_date(target_date)`

문제의 근원지:

- 홈 caller가 스토리 카드 상태를 읽지 않고 질문 detail 조합 결과를 직접 읽는다.
- 오늘과 과거의 read 경로가 서로 다르다.
- 홈 CTA 판단이 질문 존재 여부에만 묶여 있다.

### 2.2 질문 상세 화면

현재 호출 경로:

1. `/home/question`, `/calendar/question`
2. `TodayQuestionAnswerScreen`
3. `questionDetailNavigationProvider(targetDate)`
4. `questionDetailProvider(targetDate)`

질문 수정 화면 호출 경로:

1. `/home/question/edit`
2. `TodayQuestionAnswerEditScreen`
3. `todayQuestionControllerProvider`
4. `todayAnswerControllerProvider`
5. submit 시 `submit_today_question_answer()`

문제의 근원지:

- 상세 화면도 날짜 aggregate가 아니라 질문 조합 provider를 기준으로 읽는다.
- 질문 수정 화면 역시 today 전용 provider에 직접 결합되어 있다.
- 질문 route가 스토리 루프의 하위 경로가 아니라 독립 상위 경로처럼 동작한다.

### 2.3 캘린더 화면

현재 호출 경로:

1. `CalendarScreen`
2. `_CalendarGrid`
   - 날짜 숫자만 그림
   - 월간 스토리 요약 provider 없음
3. `_CalendarDetail`
   - `dailyQuestionHistoryProvider(selectedDate)`
   - `coupleExpressionSummaryProvider(selectedDate)`

문제의 근원지:

- grid가 날짜별 카드 상태를 읽을 수 없다.
- 상세 패널이 질문 history row를 기준으로 구성되어 있다.
- 월간 조회와 일간 조회의 기준 aggregate가 다르다.

### 2.4 라우터와 셸

관련 파일:

- `apps/mobile/lib/app/router.dart`
- `apps/mobile/lib/features/shell/presentation/app_shell.dart`

현재 질문 경로:

- `/home/question`
- `/home/question/edit`
- `/calendar/question`

현재 문제:

- route 이름과 caller 역할이 모두 질문 중심으로 잡혀 있다.
- 요구사항 기준으로 상위 도메인은 질문이 아니라 하루 공용 스토리 루프다.

## 3. 전환 목표 구조

## 3.1 새 read 도메인 모듈

새 read 전용 모듈은 `features/story_loops`로 추가한다.

권장 구조:

```text
apps/mobile/lib/features/story_loops/
  application/
    today_story_loop_summary_provider.dart
    story_loop_detail_provider.dart
    story_loop_detail_navigation_provider.dart
    story_loop_month_summary_provider.dart
  data/
    story_loop_read_repository.dart
    today_story_loop_summary.dart
    story_loop_detail.dart
    story_loop_month_summary.dart
    story_loop_card_preview.dart
    story_loop_question_state.dart
```

이 구조를 쓰는 이유:

- 7단계에서 만든 read RPC 3개가 모두 같은 도메인 묶음이다.
- repository를 하나로 묶어 RPC 응답 변환과 예외 매핑을 공통화할 수 있다.
- 기존 `questions` feature는 질문 leaf UI를 보관하는 범위로 축소할 수 있다.

## 3.2 provider 계약

상위 caller가 읽을 provider는 아래 네 개로 고정한다.

1. `todayStoryLoopSummaryProvider`
2. `storyLoopDetailProvider(date)`
3. `storyLoopMonthSummaryProvider(month)`
4. `storyLoopDetailNavigationProvider(date)`

각 책임은 다음과 같다.

- `todayStoryLoopSummaryProvider`
  - 홈 전용
  - RPC `get_today_story_loop_summary()`
  - 최소 상태
    - 오늘 카드 없음
    - 내가 먼저 올림 + 상대 대기
    - 상대가 먼저 올림 + 내 작성 대기
    - 양쪽 카드 완료 + 질문 생성 중
    - 질문 생성 완료
    - archived 읽기 전용
- `storyLoopDetailProvider(date)`
  - 질문 상세와 캘린더 일간 상세 공용
  - RPC `get_story_loop_detail(target_date)`
- `storyLoopMonthSummaryProvider(month)`
  - 월간 캘린더 grid 전용
  - RPC `get_story_loop_month_summary(target_month)`
- `storyLoopDetailNavigationProvider(date)`
  - 이전 날짜, 다음 날짜 계산 전용
  - couple 시작일과 현재 날짜 범위만 관리

고정 규칙:

- 홈, 상세, 캘린더 상위 caller는 직접 `questionDetailProvider`, `todayQuestionControllerProvider`, `todayAnswerControllerProvider`, `dailyQuestionHistoryProvider`를 읽지 않는다.
- 질문 UI는 `storyLoopDetail` 내부의 `dailyQuestion` 하위 상태만 사용한다.

## 4. 화면별 caller 전환

### 4.1 홈 화면

대상 파일:

- `apps/mobile/lib/features/home/presentation/home_screen.dart`

전환 방향:

- 현재 `_QuestionCharacterPreview`가 맡고 있는 단일 중앙 caller를 그대로 이름만 바꾸면 안 된다.
- 홈은 `캐릭터 오브젝트`와 `스토리 카드 오브젝트`를 서로 다른 sibling으로 유지해야 한다.
- 따라서 홈 caller 전환은 `질문 미리보기 위젯 치환`이 아니라 `캐릭터 영역 유지 + 스토리 카드 영역 분리`로 설계해야 한다.
- 스토리 카드 영역을 맡는 caller는 역할상 `HomeStoryLoopPreview`로 두는 편이 맞다.
- 이 스토리 카드 영역은 `todayStoryLoopSummaryProvider`만 읽는다.

CTA 판단 규칙:

1. 오늘 카드 없음
   - 빈 슬롯 + 오늘 카드 작성 진입
2. 내가 먼저 올림
   - 내 카드 preview + 상대 대기 상태
   - 필요 시 내 카드 수정 진입
3. 상대가 먼저 올림
   - 상대 카드 preview + 내 작성 진입
4. 양쪽 카드 완료, 질문 생성 전
   - `질문 생성 중` 상태 노출
5. `dailyQuestionId != null && myAnswerExists = false`
   - 질문 답변 작성 진입
6. `dailyQuestionId != null && myAnswerExists = true`
   - 질문 상세 진입
7. `archivedReadOnly = true`
   - 읽기 전용 preview만 제공

유지되는 것:

- 캐릭터 진입 구조
- 표현 버튼
- 메인 화면의 녹음 버튼과 목록 진입 구조

즉 홈은 정보 구조만 스토리 루프 중심으로 바뀌는 것이 아니라, 현재 질문 preview 슬롯을 `캐릭터`와 `스토리 카드`의 분리된 구조로 다시 쪼개야 한다. 다만 캐릭터 진입, 표현 버튼, 녹음 메인 버튼과 보관함 진입 구조는 유지한다.

### 4.2 질문 상세 화면

대상 파일:

- `apps/mobile/lib/features/questions/presentation/today_question_answer_screen.dart`

전환 방향:

- `questionDetailProvider(targetDate)`를 `storyLoopDetailProvider(targetDate)`로 교체한다.
- `questionDetailNavigationProvider(targetDate)`를 `storyLoopDetailNavigationProvider(targetDate)`로 교체한다.

질문 화면의 실제 역할:

- 특정 날짜의 스토리 루프를 읽는다.
- 그 루프 안에 질문이 생성되어 있으면 질문 leaf UI를 렌더링한다.
- 질문이 아직 생성되지 않았으면 질문 미생성 상태를 보여준다.

재사용 유지 대상:

- `QuestionDetailHeader`
- `QuestionPromptCharacter`
- `QuestionAnswerOverview`
- `MyQuestionAnswerSection`
- `PartnerQuestionAnswerSection`

즉 질문 화면의 UI 뼈대는 재사용하되, read 계약만 story loop detail로 바꾼다.

### 4.3 질문 수정 화면

대상 파일:

- `apps/mobile/lib/features/questions/presentation/today_question_answer_screen.dart`
  - `TodayQuestionAnswerEditScreen`

전환 방향:

- 초기 read는 `storyLoopDetailProvider(today)`에서 가져온다.
- submit write는 당장은 기존 `submit_today_question_answer()`를 유지할 수 있다.
- 다만 submit 전 검증을 위해 read를 다시 `todayQuestionControllerProvider`에 의존하는 구조는 제거한다.
- 홈과 캘린더 양쪽에서 오늘 질문 수정이 가능하므로, 질문 수정 route는 `진입 출처`를 보존해야 한다.
- 즉 수정 화면에서 저장 또는 뒤로 가기 시 원래 진입한 출처로 복귀해야 한다.

진입 출처 보존 계약:

1. 질문 상세 화면은 edit 진입 시 `source` query parameter를 함께 넘긴다.
   - 홈 상세에서 진입: `source=home`
   - 캘린더 상세에서 진입: `source=calendar`
2. 캘린더에서 진입한 경우에는 현재 열고 있던 날짜를 `date=yyyy-mm-dd`로 함께 넘긴다.
3. edit 화면은 `source`와 `date`를 route builder에서 파싱해 복귀 경로 계산에 사용한다.
4. 저장 성공 후 복귀 규칙
   - `source=home` -> `/home/question`
   - `source=calendar` -> `/calendar/question?date=...`
5. 뒤로 가기 복귀 규칙
   - navigation stack 에 pop 대상이 있으면 우선 `pop`
   - 직접 진입 등으로 pop 대상이 없으면 위 복귀 경로로 `go`

이 계약을 쓰는 이유:

- 현재 상세 화면은 `backLocation`으로 홈과 캘린더를 구분하고 있다.
- 반면 edit 화면은 여전히 `/home/question/edit` 단일 route와 `/home/question` 고정 복귀에 묶여 있다.
- 따라서 edit route에 `source`와 `date`를 싣는 것이 현재 구조를 가장 적게 흔들면서도 caller 전환 이후의 복귀 일관성을 보장하는 최소 변경이다.

이유:

- read caller를 이미 `storyLoopDetailProvider(today)`로 통일했는데, submit 직전에 다시 question today provider를 읽으면 구조가 다시 분리된다.
- 수정 화면도 상위 기준 aggregate는 story loop여야 한다.
- 현재처럼 홈 전용 edit route에 고정하면 캘린더 진입 수정 플로우가 다시 홈으로 튀는 결합이 남는다.

### 4.4 캘린더 grid

대상 파일:

- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`

전환 방향:

- `_CalendarGrid`는 `storyLoopMonthSummaryProvider(_visibleMonth)`를 읽는다.
- 각 날짜 셀은 month summary에 포함된 카드 수와 정렬 정보만 사용한다.
- 월간 셀 탭의 기본 동작은 `_selectedDate`를 갱신하고, 같은 화면 안의 상세 패널 caller를 바꾸는 것이다.

표현 규칙:

- 0장: 기존 날짜 숫자만 보임
- 1장: 카드 1장만 곧게 보임
- 2장: 업로드 시간 순으로 2장 겹침 표시

주의:

- grid는 질문 본문이나 답변 본문을 읽지 않는다.
- grid는 월간 요약만 소비한다.
- 따라서 현재 `CalendarScreen` 내부의 `selectedDate -> inline detail panel` 구조는 유지하되, 상세 패널의 read caller만 `storyLoopDetailProvider(selectedDate)`로 전환한다.

### 4.5 캘린더 일간 상세

대상 파일:

- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`

전환 방향:

- 캘린더 일간 상세의 1차 진입점은 계속 월간 셀 탭 이후의 인라인 상세 패널이다.
- 그 상세 패널의 read caller는 `storyLoopDetailProvider(selectedDate)`다.
- `coupleExpressionSummaryProvider(selectedDate)`는 이번 단계에서는 유지한다.

이유:

- story loop detail RPC는 카드, 질문, 답변 aggregate를 책임진다.
- 표현 요약은 아직 별도 계약이므로 현재는 병렬 조합으로 둔다.
- 사용자가 선택한 요구사항에 따라 캘린더는 별도 날짜 상세 route를 도입하지 않고, 현재 화면 안의 인라인 상세 패널 구조를 유지한다.

## 5. route 경계 재정의

질문 route 문자열은 당장 유지한다.

- `/home/question`
- `/home/question/edit`
- `/calendar/question`

하지만 역할은 바뀐다.

- 이전: 질문 도메인 직접 진입 경로
- 이후: 스토리 루프 내부의 질문 leaf 경로

이번 단계에서 먼저 고정할 것은 route literal이 아니라 route 역할이다.

1. 오늘 홈에서의 질문 진입은 `todayStoryLoopSummary`를 기준으로 결정된다.
2. 캘린더 질문 진입은 `storyLoopDetail(date)`를 기준으로 결정된다.
3. 캘린더 월간 셀 탭은 현재 화면 안에서 `selectedDate`와 상세 패널 상태를 갱신해야 한다.
4. 오늘 질문 수정 route는 홈과 캘린더 양쪽에서 진입 가능해야 하며, 저장 및 뒤로 가기 시 진입 출처를 유지해야 한다.
5. 추후 스토리 편집 route가 추가되더라도 질문 route는 하위 leaf 경로로 유지한다.

질문 edit route의 이번 단계 고정안:

- route literal은 우선 `/home/question/edit`를 유지한다.
- 대신 route query에 `source`와 필요 시 `date`를 포함시켜 홈/캘린더 출처를 구분한다.
- 즉 이번 단계에서 바꾸는 것은 path 자체가 아니라, edit route가 복귀 맥락을 보존하는 방식이다.

## 6. 정리 대상 provider

caller 전환 이후 직접 소비를 끊을 대상:

- `questionDetailProvider`
- `dailyQuestionHistoryProvider`
- `todayQuestionControllerProvider`
- `todayAnswerControllerProvider`

단, 제거 순서는 다음과 같이 나눈다.

1. `features/story_loops` read 계층 추가
2. 홈, 상세, 캘린더 caller 전환
3. 더 이상 caller가 없어진 기존 question-first provider 정리

즉 write 로직을 먼저 건드리지 않고 read caller부터 끊는다.

## 7. 구현 순서

2번 설계 기준 구현 순서는 아래로 잠근다.

1. `features/story_loops` read repository, 모델, provider 추가
2. 질문 상세 화면 read caller 전환
3. 캘린더 일간 상세 caller 전환
4. 캘린더 grid caller 전환
5. 홈 preview caller 전환
6. 기존 question-first provider의 직접 caller 제거

이 순서를 택하는 이유:

- 질문 화면이 가장 기존 UI 재사용 폭이 크다.
- 캘린더는 detail과 grid를 분리 전환해야 리스크가 낮다.
- 홈은 가장 상위 요약 조합이므로 마지막에 붙이는 편이 안전하다.

## 8. 최종 정리

이번 2번 단계의 핵심은 질문 기능 삭제가 아니다.

- 질문 UI는 유지한다.
- 질문 답변 write도 우선 유지한다.
- 바뀌는 것은 화면의 상위 read caller 기준이다.

최종적으로 화면별 기준 aggregate는 다음처럼 정리된다.

- 홈: `todayStoryLoopSummary`
- 날짜 상세: `storyLoopDetail`
- 월간 grid: `storyLoopMonthSummary`
- 질문 UI: `storyLoopDetail` 내부의 leaf

즉 기존 질문 중심 read 구조를 스토리 카드 루프 중심 read 구조로 재배치하는 것이 이번 단계의 정확한 범위다.
