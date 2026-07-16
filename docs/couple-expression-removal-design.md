# 커플 감정 표현 기능 제거 설계

작성일: 2026-07-16

## 1. 목적

홈의 `보고싶어`, `고마워`, `우울해`, `힘내` 버튼으로 감정을 전송하고 달력에서 일별 전송 횟수를 조회하는 기능을 완전히 제거한다.

이번 제거 범위는 현재 구현된 커플 감정 표현 기능이다. 스토리 카드의 자유 텍스트와 드로잉, 질문 답변, 향후 별도로 설계할 답변 리액션은 변경하지 않는다.

함께 변경하는 홈 헤더의 D+ 표시는 공용 제목 스타일을 변경하지 않고 24px 전용 스타일을 사용한다. 설정·달력·질문 등 다른 헤더 제목의 크기는 유지한다.

## 2. 현재 호출 경로

### 2.1 전송

1. 홈 `_ExpressionGrid`
2. `CoupleExpressionController.send`
3. `CoupleExpressionRepository.send`
4. `send_couple_expression` RPC
5. `public.couple_expressions` insert
6. Database Webhook
7. `send-expression-notification` Edge Function
8. `couple_expression` 푸시 디스패치 및 전송 결과 저장

### 2.2 조회

1. 달력 `_CalendarDetail`
2. `coupleExpressionSummaryProvider`
3. `get_couple_expression_summary_for_date` RPC
4. `public.couple_expressions` 집계
5. `CalendarStoryLoopDetail`의 `그 날의 표현 횟수`

### 2.3 설정

1. 알림 설정의 `표현 알림` 토글
2. 모바일 `NotificationPreferences.expressionEnabled`
3. `update_my_notification_preferences`의 `requested_expression_enabled`
4. `public.user_notification_preferences.expression_enabled`

## 3. 제거 범위

### 3.1 모바일

- 홈 표현 버튼, 전송 피드백, 전송 상태를 제거한다.
- 달력 표현 집계 요청과 집계 UI를 제거한다.
- `features/expressions`의 모델, 저장소, 컨트롤러, Provider를 제거한다.
- 알림 설정 모델과 화면에서 표현 알림을 제거한다.
- 커플 보관·삭제 안내에서 표현 데이터를 제거한다.
- 홈·달력·표현 전용 테스트와 fake를 제거하고 기존 스토리·질문 검증은 유지한다.

### 3.2 Supabase

- 기존 마이그레이션은 배포 이력으로 보존한다.
- 새 마이그레이션에서 다음 순서로 제거한다.
  1. 표현 전송·집계 RPC 제거
  2. 표현 알림 디스패치·전송 로그 삭제
  3. 푸시 타입 제약과 claim/complete 함수에서 `couple_expression` 제거
  4. 알림 설정 RPC에서 표현 필드 제거
  5. `expression_enabled` 컬럼 제거
  6. `couple_expressions` 테이블 제거

### 3.3 푸시 및 운영

- `send-expression-notification` 소스와 원격 Edge Function을 제거한다.
- 표현 전용 Database Webhook을 제거한다.
- 다른 Webhook의 `EXPRESSION_WEBHOOK_SECRET` fallback을 제거한다.
- 모든 푸시가 공유하던 Android 채널 ID를 `vinscent_notifications`로 교체한다.
- 전용 secret은 다른 Webhook이 각자의 secret으로 전환된 뒤 제거한다.

## 4. 보존 범위

- 스토리 카드 작성·조회·알림
- 질문 생성·답변·리마인드 알림
- 녹음 및 커플 연결 해제 알림
- 커플 아카이브와 기존 질문·카드·캐릭터 데이터
- 기존 마이그레이션에 기록된 과거 스키마 이력

기존 표현 데이터는 중요 데이터가 아니므로 새 제거 마이그레이션에서 테이블과 함께 삭제한다.

## 5. 배포 순서

1. 모바일과 Edge Function 소스 변경을 배포 준비한다.
2. `npx supabase db push`로 제거 마이그레이션을 적용한다.
3. 남아 있는 Edge Function을 전용 Webhook secret 기준으로 다시 배포한다.
4. Dashboard에서 `couple_expressions` Webhook을 제거한다.
5. `npx supabase functions delete send-expression-notification`으로 원격 함수를 제거한다.
6. 다른 함수가 전용 secret으로 동작하는 것을 확인한 뒤 `EXPRESSION_WEBHOOK_SECRET`을 제거한다.
7. 새 모바일 빌드에서 홈, 달력, 알림 설정과 나머지 푸시를 확인한다.

## 6. 구현 단계와 커밋

1. `docs: 감정 표현 기능 제거 설계 추가`
2. `refactor: 모바일 감정 표현 기능 제거`
3. `refactor: 감정 표현 백엔드 제거`

## 7. 검증 기준

- 홈에 네 개의 감정 표현 버튼이 없다.
- 달력에서 표현 집계 요청과 UI가 없다.
- 알림 설정에 표현 알림 토글이 없다.
- 모바일 소스와 현재 Edge Function에 표현 도메인 참조가 없다.
- 새 DB 최종 상태에 표현 RPC, 테이블, 알림 타입, 환경설정 컬럼이 없다.
- 다른 알림 타입은 기존 claim, complete, preference 흐름을 유지한다.
- D+는 `D+숫자` 형식을 유지하며 기존보다 크게 표시된다.
- Flutter 정적 분석과 전체 테스트가 통과한다.
