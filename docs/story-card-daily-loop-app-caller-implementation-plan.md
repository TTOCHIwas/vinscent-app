# 스토리 카드 루프 앱 caller 구현 단계 설계

작성일: 2026-07-06

이 문서는 현재 코드 기준으로 스토리 카드 루프 read 계층을 앱 화면에 붙이는 구현 단계를 정리한다. 범위는 migration 7단계 read RPC가 이미 존재한다는 전제에서, Flutter 앱의 caller를 질문 중심 구조에서 스토리 카드 루프 중심 구조로 전환하는 것이다.

기준 문서:

- `docs/story-card-daily-loop-requirements.md`
- `docs/story-card-daily-loop-contract-design.md`
- `docs/story-card-daily-loop-caller-transition-design.md`

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

## 1. 이번 단계의 목표

이번 단계의 목표는 다음 세 가지다.

1. `features/story_loops` read 계층을 실제 앱 코드에 추가한다.
2. 질문 상세, 질문 수정, 캘린더 상세, 캘린더 grid, 홈 미리보기 caller를 순서대로 `story_loops` 기준으로 교체한다.
3. 질문-first read caller 의존을 정리하되, 아직 write 경계가 옛 구조를 쓰는 부분은 성급히 제거하지 않는다.

이번 단계에서 하지 않는 일은 다음과 같다.

- story card write RPC 구현
- story card 편집 화면 구현
- today answer write 자체의 서버 경계 교체
- 녹음 UI 재배치 구현
- 위젯 구현

## 2. 현재 구조 기준 잠금 사항

구현 전에 현재 코드 기준으로 먼저 잠가야 할 사실은 다음과 같다.

### 2.1 `questionDetailProvider`와 `dailyQuestionHistoryProvider`는 이번 단계에서 대체 대상이다

근거:

- `HomeScreen`은 `questionDetailProvider(null)`를 직접 읽는다.
- `TodayQuestionAnswerScreen`은 `questionDetailProvider(targetDate)`와 `questionDetailNavigationProvider(targetDate)`를 직접 읽는다.
- `CalendarScreen`의 `_CalendarDetail`은 `dailyQuestionHistoryProvider(selectedDate)`를 직접 읽는다.

즉 이 둘은 read caller 전환이 끝나면 제거 대상이 된다.

### 2.2 `todayQuestionControllerProvider`와 `todayAnswerControllerProvider`는 이번 단계에서 완전 제거 대상이 아니다

근거:

- `TodayQuestionAnswerEditScreen`은 아직 초기 read와 submit write를 모두 이 둘에 의존한다.
- 특히 `TodayAnswerController.submit()`은 내부에서 `todayQuestionControllerProvider.future`를 읽고, `dailyQuestionAnswerRepository.submitTodayAnswer()`를 호출한다.

따라서 이번 read caller 전환 단계에서 이 둘을 즉시 삭제하면 질문 수정 저장 플로우가 깨진다.

이번 단계의 정확한 정리 원칙:

- `questionDetailProvider`, `dailyQuestionHistoryProvider`는 대체 후 제거
- `todayQuestionControllerProvider`, `todayAnswerControllerProvider`는 질문 write 전환 단계 전까지 유지

### 2.3 캘린더는 별도 date-detail route로 바꾸지 않는다

근거:

- 사용자 결정상 현재 `selectedDate -> inline detail panel` 구조를 유지해야 한다.
- 따라서 `_CalendarGrid`는 선택 상태를 갱신하고, `_CalendarDetail`만 새 caller를 읽도록 바꾼다.

### 2.4 홈은 단순 위젯 이름 교체가 아니라 정보 구조 분리가 필요하다

근거:

- 현재 홈의 중심 caller는 `_QuestionCharacterPreview` 하나에 묶여 있다.
- 요구사항은 캐릭터 오브젝트와 스토리 카드 오브젝트를 sibling으로 유지하라고 고정되어 있다.

따라서 홈 전환은 가장 마지막 단계에 둔다.

## 3. 구현 순서 고정안

이번 구현 순서는 아래로 잠근다.

1. `features/story_loops` read 계층 추가
2. 질문 상세 read caller 전환
3. 질문 수정 화면 초기 read와 출처 복귀 전환
4. 캘린더 일간 상세 caller 전환
5. 캘린더 월간 grid caller 전환
6. 홈 미리보기 caller 전환
7. 더 이상 필요 없는 질문-first read caller 정리

이 순서를 고정하는 이유는 다음과 같다.

- 질문 상세 화면이 기존 질문 UI 재사용 폭이 가장 크다.
- 질문 수정 화면은 read와 route 복귀 계약이 함께 묶여 있으므로 상세 화면 바로 다음에 붙여야 한다.
- 캘린더는 detail과 grid를 나눠서 전환해야 리스크가 낮다.
- 홈은 레이아웃 분해가 포함되므로 마지막이 맞다.
- cleanup은 실제 caller가 모두 빠진 뒤에만 안전하다.

## 4. 단계별 구현 설계

## 4.1 0단계 문서 잠금

목적:

- 이번 문서를 포함해 앱 caller 전환 구현의 기준 문서를 먼저 잠근다.

변경 파일:

- `docs/story-card-daily-loop-app-caller-implementation-plan.md`

커밋 메시지:

- `docs: 스토리 카드 루프 앱 caller 구현 단계 설계`

검증:

- 문서 기준으로 각 단계의 대상 파일과 제거 대상이 명확히 적혀 있어야 한다.

## 4.2 1단계 read 계층 추가

목적:

- 화면 교체 전에 `features/story_loops` read 모델, repository, provider를 먼저 추가한다.

신규 파일:

- `apps/mobile/lib/features/story_loops/data/story_loop_status.dart`
- `apps/mobile/lib/features/story_loops/data/story_loop_card_preview.dart`
- `apps/mobile/lib/features/story_loops/data/story_loop_card_detail.dart`
- `apps/mobile/lib/features/story_loops/data/story_loop_question_summary.dart`
- `apps/mobile/lib/features/story_loops/data/story_loop_question_detail.dart`
- `apps/mobile/lib/features/story_loops/data/today_story_loop_summary.dart`
- `apps/mobile/lib/features/story_loops/data/story_loop_detail.dart`
- `apps/mobile/lib/features/story_loops/data/story_loop_month_summary_day.dart`
- `apps/mobile/lib/features/story_loops/data/story_loop_read_repository.dart`
- `apps/mobile/lib/features/story_loops/application/today_story_loop_summary_provider.dart`
- `apps/mobile/lib/features/story_loops/application/story_loop_detail_provider.dart`
- `apps/mobile/lib/features/story_loops/application/story_loop_detail_navigation_provider.dart`
- `apps/mobile/lib/features/story_loops/application/story_loop_month_summary_provider.dart`

재사용 파일:

- `apps/mobile/lib/features/questions/data/daily_question.dart`
- `apps/mobile/lib/features/questions/data/daily_question_answer_state.dart`
- `apps/mobile/lib/features/couple/data/couple.dart`

구현 원칙:

1. repository는 `get_today_story_loop_summary`, `get_story_loop_detail`, `get_story_loop_month_summary`만 호출한다.
2. repository는 RPC row를 먼저 정규화한 뒤 `DailyQuestion`, `DailyQuestionAnswerState`로 변환한다.
3. provider는 couple/date 유효성 검사를 수행한다.
4. `empty`와 `unavailable` 해석은 provider가 담당한다.

보존되는 것:

- 기존 질문 화면과 캘린더, 홈 화면은 아직 이 계층을 읽지 않는다.

커밋 메시지:

- `feat: 스토리 카드 루프 read 계층 추가`

검증:

- `flutter analyze`
- story loop repository/provider 관련 신규 테스트 또는 최소 모델 변환 테스트

## 4.3 2단계 질문 상세 caller 전환

목적:

- `TodayQuestionAnswerScreen`의 읽기 기준을 `questionDetailProvider`에서 `storyLoopDetailProvider`로 교체한다.

대상 파일:

- `apps/mobile/lib/features/questions/presentation/today_question_answer_screen.dart`
- `apps/mobile/lib/features/story_loops/application/story_loop_detail_provider.dart`
- `apps/mobile/lib/features/story_loops/application/story_loop_detail_navigation_provider.dart`

필요 시 신규 파일:

- `apps/mobile/lib/features/questions/presentation/story_loop_question_view_model.dart`
  - 질문 UI가 필요한 최소 데이터를 story loop detail에서 추출하는 adapter

구현 원칙:

1. 질문 화면의 상위 read는 `storyLoopDetailProvider(targetDate)` 하나만 읽는다.
2. 좌우 스와이프 이동은 `storyLoopDetailNavigationProvider(targetDate)`를 읽는다.
3. 질문 leaf UI 자체는 최대한 유지한다.
4. 질문이 없는 날짜는 기존 `noQuestion` 메시지가 아니라 story loop 기준 미생성 상태를 해석해 보여준다.

보존되는 것:

- `QuestionDetailHeader`
- `QuestionPromptCharacter`
- `QuestionAnswerOverview`
- `MyQuestionAnswerSection`
- `PartnerQuestionAnswerSection`

이번 단계에서 제거하지 않는 것:

- `todayQuestionControllerProvider`
- `todayAnswerControllerProvider`

이유:

- 질문 수정 저장 경계가 아직 이 둘에 의존하기 때문이다.

커밋 메시지:

- `feat: 질문 상세를 스토리 카드 루프 detail로 전환`

검증:

- `flutter analyze`
- `test/features/questions/presentation/today_question_answer_screen_test.dart`
- 오늘/과거/미래/관계 시작일 이전 날짜 케이스 수동 확인

## 4.4 3단계 질문 수정 화면 전환

목적:

- 질문 수정 화면의 초기 read를 `storyLoopDetailProvider`로 바꾸고, 출처 복귀 계약을 실제 route에 반영한다.

대상 파일:

- `apps/mobile/lib/features/questions/presentation/today_question_answer_screen.dart`
- `apps/mobile/lib/app/router.dart`
- `apps/mobile/lib/features/shell/presentation/app_shell.dart`

필요 시 신규 파일:

- `apps/mobile/lib/features/questions/presentation/question_route_context.dart`
  - `source`, `date` 파싱과 fallback location 계산 전용

구현 원칙:

1. 상세 화면에서 edit 진입 시 `source=home|calendar`를 query로 전달한다.
2. 캘린더 진입이면 `date=yyyy-mm-dd`도 함께 전달한다.
3. edit 화면의 초기 read는 `storyLoopDetailProvider(today)` 또는 전달된 today date 기준 데이터를 쓴다.
4. 저장 write는 당장은 `todayAnswerControllerProvider.notifier.submit()`를 유지한다.
5. 저장 후와 뒤로 가기 시 출처에 맞춰 복귀한다.

보존되는 것:

- `submit_today_question_answer()` 서버 write
- `todayAnswerControllerProvider.notifier.submit()` 호출 방식

이번 단계에서 제거하지 않는 것:

- `todayQuestionControllerProvider`
- `todayAnswerControllerProvider`

이유:

- submit write 경계가 아직 옛 구조를 사용한다.

커밋 메시지:

- `feat: 질문 수정 화면 출처 복귀와 루프 read 전환`

검증:

- `flutter analyze`
- 홈에서 edit 진입 후 저장/뒤로 가기 복귀
- 캘린더에서 edit 진입 후 저장/뒤로 가기 복귀
- archived read-only 차단 확인

## 4.5 4단계 캘린더 일간 상세 caller 전환

목적:

- `_CalendarDetail`의 질문 history 직접 조회를 끊고 `storyLoopDetailProvider(selectedDate)` 기준으로 상세를 렌더링한다.

대상 파일:

- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`

필요 시 신규 파일:

- `apps/mobile/lib/features/calendar/presentation/widgets/calendar_story_loop_detail.dart`
- `apps/mobile/lib/features/calendar/presentation/widgets/calendar_story_card_stack.dart`

구현 원칙:

1. `_CalendarDetail`은 `storyLoopDetailProvider(selectedDate)`와 `coupleExpressionSummaryProvider(selectedDate)`를 병렬로 읽는다.
2. 스토리 카드 0/1/2장 상태를 질문 leaf와 별도로 보여준다.
3. 질문이 있으면 기존 질문 answer section을 재사용한다.
4. 오늘 날짜이며 질문 편집 가능 상태면 기존 질문 수정 진입을 유지한다.

보존되는 것:

- `selectedDate -> inline detail panel` 구조
- 표현 요약 병렬 표시

제거되는 직접 caller:

- `dailyQuestionHistoryProvider(selectedDate)`의 캘린더 직접 사용

커밋 메시지:

- `feat: 캘린더 상세를 스토리 카드 루프 detail로 전환`

검증:

- `flutter analyze`
- `test/features/calendar/presentation/calendar_screen_test.dart`
- 카드만 있는 날짜 / 질문까지 있는 날짜 / 아무것도 없는 날짜 수동 확인

## 4.6 5단계 캘린더 월간 grid 전환

목적:

- `_CalendarGrid`가 날짜 숫자만 그리던 구조를 `storyLoopMonthSummaryProvider(_visibleMonth)` 기반으로 바꾼다.

대상 파일:

- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`

필요 시 신규 파일:

- `apps/mobile/lib/features/calendar/presentation/widgets/calendar_month_story_cell.dart`

구현 원칙:

1. 월간 grid는 `storyLoopMonthSummaryProvider(_visibleMonth)`만 읽는다.
2. 0장은 기존 날짜 숫자만 보인다.
3. 1장은 단독 카드, 2장은 업로드 시간 순 겹침 카드로 표시한다.
4. month summary는 질문/답변 텍스트를 읽지 않는다.

보존되는 것:

- 날짜 범위 enable/disable 계산
- `_selectedDate` 갱신 방식

커밋 메시지:

- `feat: 캘린더 월간 그리드에 스토리 카드 요약 반영`

검증:

- `flutter analyze`
- `test/features/calendar/presentation/calendar_screen_test.dart`
- 한 달 안에서 0장/1장/2장 셀 표현 확인

## 4.7 6단계 홈 caller 전환

목적:

- 홈의 질문 중심 미리보기를 `todayStoryLoopSummaryProvider` 기반으로 교체하고, 캐릭터 영역과 스토리 카드 영역을 분리한다.

대상 파일:

- `apps/mobile/lib/features/home/presentation/home_screen.dart`

필요 시 신규 파일:

- `apps/mobile/lib/features/home/presentation/widgets/home_story_loop_preview.dart`
- `apps/mobile/lib/features/home/presentation/widgets/home_character_area.dart`

구현 원칙:

1. 홈은 `캐릭터 오브젝트`와 `스토리 카드 오브젝트`를 sibling으로 나눈다.
2. 스토리 카드 영역만 `todayStoryLoopSummaryProvider`를 읽는다.
3. CTA는 아래 상태를 정확히 구분한다.
   - 오늘 카드 없음
   - 내가 먼저 올림
   - 상대가 먼저 올림
   - 양쪽 카드 완료 + 질문 생성 중
   - 질문 생성 완료 + 내 답변 전
   - 질문 생성 완료 + 내 답변 후
   - archived read-only
4. 표현 버튼, 녹음 패널, 커플 상태 표시 구조는 유지한다.

보존되는 것:

- `_CoupleStatus`
- `HomeRecordingPanel`
- `_ExpressionGrid`

제거되는 직접 caller:

- `questionDetailProvider(null)`의 홈 직접 사용

커밋 메시지:

- `feat: 홈 스토리 카드 미리보기 caller 전환`

검증:

- `flutter analyze`
- `test/features/home/presentation/home_screen_test.dart`
- 홈에서 no card / partner first / my first / question generating / answer pending 흐름 수동 확인

## 4.8 7단계 질문-first read caller 정리

목적:

- 더 이상 직접 caller가 없는 질문-first read provider를 정리한다.

대상 파일:

- `apps/mobile/lib/features/questions/application/question_detail_provider.dart`
- `apps/mobile/lib/features/questions/application/question_detail_navigation_provider.dart`
- `apps/mobile/lib/features/questions/application/daily_question_history_provider.dart`
- 질문 상세/캘린더/홈에서 관련 import가 남아 있는 파일

정리 원칙:

1. 홈, 질문 상세, 캘린더에서 더 이상 읽지 않는 provider만 제거한다.
2. `todayQuestionControllerProvider`, `todayAnswerControllerProvider`는 유지한다.
3. cleanup 단계에서 write 경계까지 건드리지 않는다.

이번 단계에서 유지되는 것:

- `todayQuestionControllerProvider`
- `todayAnswerControllerProvider`
- `DailyQuestionRepository`
- `DailyQuestionAnswerRepository`

이유:

- 질문 수정 submit 경계가 아직 이들에 기대고 있기 때문이다.

커밋 메시지:

- `chore: 질문 중심 read caller 의존 정리`

검증:

- `flutter analyze`
- 질문 화면, 캘린더, 홈 import 정리 확인

## 5. 단계별 테스트 묶음

구현할 때는 각 단계 커밋 직전에 아래 범위만 검증한다.

### 5.1 공통

- `flutter analyze`

### 5.2 질문 상세 / 수정 단계

- `test/features/questions/presentation/today_question_answer_screen_test.dart`
- `test/features/shell/app_shell_routing_test.dart`

### 5.3 캘린더 단계

- `test/features/calendar/presentation/calendar_screen_test.dart`

### 5.4 홈 단계

- `test/features/home/presentation/home_screen_test.dart`

## 6. 최종 잠금 사항

이번 구현 설계에서 가장 중요한 잠금은 아래 두 가지다.

1. read caller cleanup과 question write cleanup은 같은 단계가 아니다.
2. 홈 전환은 질문 preview 교체가 아니라 캐릭터와 스토리 카드의 구조 분리다.

즉 구현할 때는 다음처럼 움직여야 한다.

- 먼저 새 read 계층을 추가한다.
- 그 다음 화면 caller를 순서대로 교체한다.
- 마지막에 더 이상 안 쓰는 read caller만 정리한다.
- question submit write 경계는 다음 테스크에서 다룬다.
