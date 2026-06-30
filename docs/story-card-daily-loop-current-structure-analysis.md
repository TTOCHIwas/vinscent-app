# 스토리 카드 전환 현재 구조 분석

작성일: 2026-06-29

## 1. 문서 목적

이 문서는 `오늘의 질문 -> 각자 답변` 중심 구조를 `스토리 카드 작성 -> 질문 생성 -> 각자 답변` 구조로 전환하기 전에, 현재 코드베이스가 어떤 축을 중심으로 동작하는지 실제 파일 기준으로 정리한 분석 문서다.

분석 범위는 다음 3단계다.

1. 하루 부모 엔티티 분석
2. 홈 화면 영향 범위 분석
3. 캘린더 / 알림 / 위젯 축 분석

모든 판단은 현재 저장소 내부 파일만을 근거로 한다.

## 2. 요약 결론

- 현재 하루 단위 부모 엔티티는 `story card`가 아니라 `daily_questions`다.
- 홈 화면의 중앙 핵심 패널은 질문 상태와 질문 라우팅에 강하게 결합돼 있다.
- 캘린더는 하루 기록의 대표 단위를 질문으로 보고 있다.
- 알림 인프라는 재사용 가능하지만, 이벤트 종류와 스케줄링 기준은 질문 중심으로 설계돼 있다.
- 위젯 기능은 현재 저장소 기준으로 미구현 상태다.

즉, 이번 전환은 단순 UI 교체가 아니라 `하루 대표 단위`, `홈 상태 모델`, `기록 조회 구조`, `알림 이벤트 구조`를 재정의하는 작업이다.

## 3. 1단계 분석: 하루 부모 엔티티

## 3.1 현재 결론

현재 코드에서 하루 단위 부모 엔티티는 `public.daily_questions`다. 이 결론은 조회, 답변 제출, 과거 기록, 알림의 4개 독립 경로가 모두 `daily_questions`를 기준으로 움직인다는 점으로 확인된다.

아래 근거는 최초 생성 마이그레이션이 아니라, 같은 함수명이 이후 `create or replace function`으로 갱신된 경우 현재 최종적으로 유효한 정의 기준으로 적는다.

## 3.2 홈 조회 경로

호출 흐름:

1. `apps/mobile/lib/features/home/presentation/home_screen.dart`
   - `_QuestionCharacterPreview`
   - `questionDetailProvider(null)` 호출
2. `apps/mobile/lib/features/questions/application/question_detail_provider.dart`
   - 오늘 날짜가 편집 가능한 경우 `todayQuestionControllerProvider.future` 호출
3. `apps/mobile/lib/features/questions/application/today_question_controller.dart`
   - `fetchTodayQuestion()` 호출
4. `apps/mobile/lib/features/questions/data/daily_question_repository.dart`
   - RPC `get_or_assign_today_question` 호출
5. `supabase/migrations/20260531006000_create_daily_question_answers.sql`
   - `public.get_or_assign_today_question()` 현재 유효 공개 RPC 정의
   - 내부에서 `private.get_or_assign_today_daily_question()` 호출
6. `supabase/migrations/20260623004000_add_service_role_notification_helpers.sql`
   - `private.get_or_assign_today_daily_question()` 현재 유효 내부 정의
   - `private.get_or_assign_daily_question_for_couple()`로 위임해 커플 timezone 기준 오늘 날짜의 `daily_questions` 행을 확보

핵심:

- 홈의 질문 패널은 모든 홈 상태가 아니라, 활성 커플이면서 오늘 편집 가능한 경로에서만 이 흐름을 탄다.
- 이 경로는 단순 조회가 아니라 필요 시 오늘의 `daily_questions` 행 생성까지 포함한다.

## 3.3 답변 제출 경로

호출 흐름:

1. `apps/mobile/lib/features/questions/presentation/today_question_answer_screen.dart`
   - `_AnswerForm._submit()`
2. `apps/mobile/lib/features/questions/application/today_answer_controller.dart`
   - `submit(String answerText)` 
3. `apps/mobile/lib/features/questions/data/daily_question_answer_repository.dart`
   - RPC `submit_today_question_answer` 호출
4. `supabase/migrations/20260601000000_reveal_completed_daily_question_answers.sql`
   - `public.submit_today_question_answer(text)` 현재 유효 공개 RPC 정의
   - 내부에서 `private.get_or_assign_today_daily_question()` 먼저 호출
   - 이후 `daily_question_answers` upsert
   - 마지막에 `daily_questions.status` 갱신
5. `supabase/migrations/20260623004000_add_service_role_notification_helpers.sql`
   - `private.get_or_assign_today_daily_question()` 현재 유효 내부 정의
   - 답변 저장도 최종적으로 커플 timezone 기준 오늘의 `daily_questions` 확보 위에서 동작

핵심:

- 답변 저장은 `daily_question_answers`만 건드리는 것이 아니다.
- 항상 부모인 `daily_questions`를 먼저 확보하고, 그 상태까지 갱신한다.

## 3.4 과거 기록 조회 경로

호출 흐름:

1. `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`
   - `_CalendarDetail`
   - `dailyQuestionHistoryProvider(selectedDate)` 호출
2. `apps/mobile/lib/features/questions/application/daily_question_history_provider.dart`
   - `repository.fetchByDate(date)` 호출
3. `apps/mobile/lib/features/questions/data/daily_question_history_repository.dart`
   - RPC `get_daily_question_answer_state_for_date` 호출
4. `supabase/migrations/20260623001000_add_readable_access_and_couple_timezone_dates.sql`
   - `public.get_daily_question_answer_state_for_date(date)` 현재 유효 공개 RPC 정의
   - `private.get_readable_couple_for_current_user()`로 읽기 가능한 커플을 먼저 확정
   - 커플 timezone 기준 현재 날짜 범위를 검증한 뒤
   - `public.daily_questions`를 기준 테이블로 사용
   - `questions`, `private.get_today_question_answer_state()`를 조합해 반환

핵심:

- 캘린더에서 하루 기록의 대표 단위도 질문이다.
- 읽기 전용 보관 상태까지 포함해도 과거 기록 구조는 여전히 `daily_questions`를 기준으로 묶여 있다.

## 3.5 알림 경로

### 3.5.1 답변 완료 알림

호출 흐름:

1. `supabase/functions/send-answer-complete-notification/index.ts`
2. RPC `get_daily_question_answer_notification_context`
3. `supabase/migrations/20260623004000_add_service_role_notification_helpers.sql`
   - `daily_question_answers`
   - `daily_questions`
   - `couples`
   조합으로 컨텍스트 구성

핵심:

- 상대 답변 완료 알림도 `daily_question_id`를 컨텍스트 기준으로 사용한다.

### 3.5.2 오늘 질문 도착 / 미답변 리마인드 알림

호출 흐름:

1. `supabase/functions/dispatch-scheduled-notifications/index.ts`
2. 사용자별 `daily_question_delivery_time`, `daily_question_enabled`, `reminder_enabled` 조회
3. RPC `get_or_assign_daily_question_for_couple` 호출
4. `supabase/migrations/20260623004000_add_service_role_notification_helpers.sql`
   - service role 전용 `get_or_assign_daily_question_for_couple`
   - 커플 timezone 기준 해당 날짜 `daily_questions` 확보
5. `daily_question_answers`를 조회해 미답변 대상 필터링

핵심:

- 스케줄 알림도 질문 중심이다.
- 알림 시각에 맞춰 질문 부모 행을 먼저 확보한 뒤 발송한다.

## 3.6 1단계 분석 결론

현재 코드에서는 `daily_questions`가 다음 4역할을 동시에 담당한다.

- 오늘 조회 부모
- 답변 저장 부모
- 과거 기록 부모
- 알림 컨텍스트 부모

따라서 스토리 카드 전환에서 가장 먼저 고려해야 할 구조적 근원지는 `daily_questions`가 하루 대표 엔티티 자리를 이미 차지하고 있다는 점이다.

## 4. 2단계 분석: 홈 화면 영향 범위

## 4.1 현재 결론

홈 전체가 질문 중심인 것은 아니다. 실제로 질문 중심 결합이 강한 부분은 홈의 중앙 메인 패널이며, 이 패널이 상태 조회, 문구 결정, 라우팅 결정까지 함께 담당하고 있다.

## 4.2 직접 영향 파일

- `apps/mobile/lib/features/home/presentation/home_screen.dart`
- `apps/mobile/lib/app/router.dart`
- `apps/mobile/lib/features/shell/presentation/app_shell.dart`
- `apps/mobile/test/features/home/presentation/home_screen_test.dart`
- `apps/mobile/test/features/shell/app_shell_routing_test.dart`

## 4.3 홈 내부 구조 분석

현재 홈의 주요 구성:

- `_CoupleStatus()`
- `_QuestionCharacterPreview()`
- `HomeRecordingPanel()`
- `_ExpressionGrid()`

이 중 질문 중심 결합의 핵심은 `_QuestionCharacterPreview()`다.

파일:

- `apps/mobile/lib/features/home/presentation/home_screen.dart`

현재 흐름:

1. 커플 상태 확인
2. 읽기 전용 보관 상태 분기
3. `questionDetailProvider(null)` 호출
4. `LoadedQuestionDetailState` 또는 `UnavailableQuestionDetailState` 분기
5. 메시지 생성
6. 탭 시 질문 보기 또는 질문 편집으로 이동

즉 이 패널은 단순 표시 위젯이 아니라 다음을 모두 담당한다.

- 상태 판단
- 사용자 메시지 결정
- 주요 탭 행동 결정

## 4.4 홈 메시지 규칙

현재 메시지 기준:

- 질문 없음
- 질문 로딩
- 질문 로드 실패
- 상대 답변 완료
- 내 답변 완료 후 상대 대기
- 질문 본문 노출
- 답변 완료 후 AI placeholder

즉 홈의 메인 문구 기준이 `DailyQuestion`과 `DailyQuestionAnswerState`에 묶여 있다.

새 구조에서는 최소한 다음 상태 모델이 별도로 필요하다.

- 아무도 오늘 카드 안 올림
- 나만 올림
- 상대만 올림
- 양쪽 모두 올림
- 질문 생성 완료
- 답변 진행 중
- 답변 완료

## 4.5 홈 라우팅 영향

현재 홈 메인 패널은 다음 경로로 직접 이동한다.

- `/home/question`
- `/home/question/edit`
- `/home/character`

관련 파일:

- `apps/mobile/lib/features/home/presentation/home_screen.dart`
- `apps/mobile/lib/app/router.dart`

즉 홈이 스토리 카드 중심이 되면 다음이 함께 바뀐다.

- 메인 탭 대상 경로
- 편집 경로의 읽기 전용 차단 정책
- 캐릭터 편집기의 홈 진입 역할

## 4.6 숨은 캐릭터 결합

현재 홈 중앙 패널은 `CharacterSpeechPrompt`를 사용한다.

관련 파일:

- `apps/mobile/lib/features/questions/presentation/widgets/character_speech_prompt.dart`
- `apps/mobile/lib/features/characters/presentation/widgets/couple_character_avatar.dart`
- `apps/mobile/lib/features/characters/application/couple_character_controller.dart`

중요한 점:

- `CharacterSpeechPrompt` 내부는 말풍선만 렌더링하지 않는다.
- 내부에서 `CoupleCharacterAvatar`를 붙이고,
- 이 아바타는 다시 `coupleCharacterControllerProvider`를 읽는다.

즉 현재 홈 중앙 패널은 질문 상태뿐 아니라 캐릭터 이미지 상태까지 암묵적으로 끌어오고 있다.

따라서 스토리 카드 중심 전환 시에는 다음을 결정해야 한다.

- 이 컴포넌트 구조를 계속 쓸 것인지
- 스토리 카드용 홈 중심 컴포넌트를 새로 분리할 것인지

## 4.7 테스트 결합도

### 4.7.1 홈 테스트

관련 파일:

- `apps/mobile/test/features/home/presentation/home_screen_test.dart`

현재 검증 내용:

- 오늘 질문 준비 안 됨
- 오늘 질문 로딩
- 오늘 질문 로드 실패
- 상대 답변 완료 문구
- AI placeholder 문구
- 질문 본문 노출

즉 테스트가 이미 질문 중심 메시지와 상태 흐름을 전제로 하고 있다.

### 4.7.2 쉘 라우팅 테스트

관련 파일:

- `apps/mobile/test/features/shell/app_shell_routing_test.dart`

현재 검증 내용:

- 홈에서 질문 텍스트 탭 시 질문 상세 이동
- 홈에서 상대 답변 대기 문구 탭 시 질문 상세 이동
- 홈에서 AI placeholder 탭 시 질문 상세 이동

즉 홈의 메인 행동 규칙이 테스트에 직접 반영돼 있다.

## 4.8 2단계 분석 결론

홈 전환의 직접 영향 범위는 `홈 전체`라기보다 다음에 집중된다.

- 중앙 메인 패널
- 그 패널이 읽는 상태 공급자
- 그 패널의 탭 행동
- 그 패널과 연결된 shell 노출 규칙
- 그 패널을 검증하는 테스트

반면 녹음 패널, 표현 버튼, 하단 탭의 홈 선택 상태 자체는 상대적으로 영향이 적다.

## 5. 3단계 분석: 캘린더 / 알림 / 위젯

## 5.1 캘린더 축 결론

캘린더는 현재 하루 기록의 대표 단위를 완전히 질문으로 보고 있다.

관련 파일:

- `apps/mobile/lib/features/calendar/presentation/calendar_screen.dart`
- `apps/mobile/lib/features/questions/application/daily_question_history_provider.dart`
- `apps/mobile/lib/features/questions/data/daily_question_history_repository.dart`
- `apps/mobile/lib/features/questions/data/daily_question_history_entry.dart`
- `supabase/migrations/20260601001000_create_daily_question_history_rpc.sql`

현재 구조:

- 날짜 선택
- `dailyQuestionHistoryProvider(date)` 조회
- `DailyQuestionHistoryEntry`
  - `question`
  - `answerState`
  조합 렌더링

현재 상세 구성:

- 질문 본문
- 내 답변
- 상대 답변
- 요약 placeholder
- AI placeholder
- 표현 요약

즉 캘린더는 단순히 질문 텍스트를 보여주는 것이 아니라, 하루 기록 구조 자체를 질문 중심으로 모델링하고 있다.

테스트도 이 구조에 강하게 묶여 있다.

관련 파일:

- `apps/mobile/test/features/calendar/presentation/calendar_screen_test.dart`

현재 테스트 검증 내용:

- `history question`
- `my answer`
- `partner answer`
- `AI 한 줄 평`
- 질문 기록 없음 상태

## 5.2 알림 축 결론

알림은 두 층으로 나눠서 봐야 한다.

### 5.2.1 모바일 설정 층

관련 파일:

- `apps/mobile/lib/features/settings/presentation/notification_settings_screen.dart`
- `apps/mobile/lib/features/settings/data/notification_preferences.dart`
- `apps/mobile/lib/features/settings/data/settings_repository.dart`
- `supabase/migrations/20260623002000_create_user_notification_preferences.sql`
- `supabase/migrations/20260626001000_add_recording_notification_preferences.sql`

현재 설정 항목:

- 표현 알림
- 상대 답변 완료
- 오늘 질문 도착
- 미답변 리마인드
- 커플 연결 해제
- 녹음 알림
- 오늘 질문 도착 시각

즉 설정 모델의 개념어 자체가 질문 중심이다.

### 5.2.2 서버 푸시 인프라 층

관련 파일:

- `supabase/functions/_shared/push.ts`
- `supabase/functions/dispatch-scheduled-notifications/index.ts`
- `supabase/functions/send-answer-complete-notification/index.ts`
- `supabase/functions/send-recording-notification/index.ts`

재사용 가능한 것:

- 공통 푸시 발송
- dispatch 중복 방지
- 토큰 비활성화
- delivery 기록

질문 중심으로 다시 설계해야 하는 것:

- `daily_question_delivery`
- `unanswered_reminder`
- `partner_answer_completed` 컨텍스트의 부모 식별자
- 사용자 설정 컬럼명과 의미

현재 스케줄 함수는 다음 전제를 가진다.

- 사용자는 질문 도착 시각을 가진다.
- 그 시각에 질문 부모 행을 확보한다.
- 1시간 뒤 미답변 여부를 검사한다.

즉 스케줄링 기준이 질문 도착 중심으로 고정돼 있다.

### 5.2.3 스토리 카드 알림의 가장 가까운 레퍼런스

현재 저장소 내부에서 새 스토리 카드 알림에 가장 가까운 패턴은 녹음 알림이다.

관련 파일:

- `supabase/functions/send-recording-notification/index.ts`

이 패턴은:

- 도메인 이벤트 테이블을 읽고
- event type으로 메시지를 분기하고
- 공통 push helper로 발송한다

즉 스토리 카드 업로드 / 질문 생성 완료 알림도 비슷한 이벤트 기반 패턴으로 설계하는 것이 현재 코드베이스와 가장 잘 맞는다.

## 5.3 위젯 축 결론

현재 저장소 기준으로 홈 위젯 기능은 미구현 상태다.

근거:

1. `apps/mobile/pubspec.yaml`에 widget bridge 패키지가 없다.
2. Android 측 `AppWidgetProvider`, `RemoteViews`, `Glance` 구현이 없다.
3. iOS 측 `WidgetKit`, `TimelineProvider` 구현이 없다.
4. Flutter 앱 코드에도 위젯 상태 동기화 API가 없다.

즉 위젯 축은 기존 질문 구조를 고치는 문제가 아니라 신규 구현 축에 가깝다.

다만 향후 위젯이 참조할 핵심 정보원은 다음이 될 가능성이 높다.

- 커플 읽기/쓰기 상태
- 오늘 날짜 기준 컨텍스트
- 홈 전용 스토리 카드 상태 provider

## 5.4 3단계 분석 결론

- 캘린더는 질문 중심 구조가 가장 깊게 박혀 있는 화면 중 하나다.
- 알림은 발송 엔진은 재사용 가능하지만 이벤트와 스케줄 기준은 다시 설계해야 한다.
- 위젯은 현재 코드베이스 안에 존재하지 않는다.

세 축은 같은 종류의 변경이 아니다.

- 캘린더: 기존 구조 해체 및 재조립
- 알림: 인프라 재사용 + 이벤트 재설계
- 위젯: 신규 축 추가

## 6. 최종 정리

1~3단계 분석 결과를 종합하면, 현재 코드베이스는 `질문 생성 -> 질문 답변` 흐름을 중심으로 구성돼 있다.

스토리 카드 전환에서 가장 먼저 바뀌어야 하는 것은 화면 문구가 아니라 다음 4개다.

1. 하루 대표 엔티티
2. 홈 중심 상태 모델
3. 캘린더 기록의 대표 단위
4. 알림 이벤트 기준

반대로 현재 그대로 재사용 가능성이 높은 것은 다음이다.

- 커플 읽기/쓰기 권한 모델
- 공통 푸시 발송 인프라
- 일부 캔버스/드로잉 기반 UI 자산
- 질문 생성 후 텍스트 답변 단계

이 문서는 이후 최종 설계 시 현재 구조의 근거 문서로 사용한다.
