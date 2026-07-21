# 푸시 알림 설정

작성일: 2026-07-21

## 1. 기준 프로젝트

현재 모바일 앱이 `SUPABASE_URL`, `SUPABASE_ANON_KEY`로 연결하는 기존 Supabase 프로젝트를 사용한다. 로컬 저장소를 원격 프로젝트에 연결할 때는 Supabase Dashboard의 Project ID를 사용한다.

```powershell
npx supabase login
npx supabase link --project-ref <SUPABASE_PROJECT_ID>
npx supabase migration list
```

로컬과 원격 마이그레이션 이력이 일치하는지 확인한 뒤에만 `db push`를 실행한다.

## 2. Firebase 준비

Firebase 프로젝트에 Android 앱과 iOS 앱을 각각 등록한다.

- Android package name: `com.vinscent.vinscent`
- iOS bundle id: `com.vinscent.vinscent`

필요 파일:

- `apps/mobile/android/app/google-services.json`
- `apps/mobile/ios/Runner/GoogleService-Info.plist`

iOS 푸시는 Apple Developer 계정, Push Notifications capability, APNs Auth Key 등록이 필요하다. Apple Developer 환경이 준비되지 않았다면 Android 실기기부터 검증한다.

## 3. Edge Function secrets

Firebase Admin SDK 서비스 계정 JSON의 아래 값을 Supabase Edge Function Secrets에 저장한다.

- `FCM_PROJECT_ID`
- `FCM_CLIENT_EMAIL`
- `FCM_PRIVATE_KEY`

Webhook과 예약 호출은 용도별 secret을 분리한다.

- `STORY_LOOP_WEBHOOK_SECRET`
- `ANSWER_WEBHOOK_SECRET`
- `RECORDING_WEBHOOK_SECRET`
- `COUPLE_WEBHOOK_SECRET`
- `SCHEDULE_WEBHOOK_SECRET`
- `APP_NOTIFICATION_WEBHOOK_SECRET`

```powershell
npx supabase secrets set FCM_PROJECT_ID=...
npx supabase secrets set FCM_CLIENT_EMAIL=...
npx supabase secrets set FCM_PRIVATE_KEY="..."
npx supabase secrets set STORY_LOOP_WEBHOOK_SECRET=...
npx supabase secrets set ANSWER_WEBHOOK_SECRET=...
npx supabase secrets set RECORDING_WEBHOOK_SECRET=...
npx supabase secrets set COUPLE_WEBHOOK_SECRET=...
npx supabase secrets set SCHEDULE_WEBHOOK_SECRET=...
npx supabase secrets set APP_NOTIFICATION_WEBHOOK_SECRET=...
```

서비스 계정 JSON 파일은 Git에 커밋하지 않는다. `FCM_PRIVATE_KEY`는 `-----BEGIN PRIVATE KEY-----`부터 `-----END PRIVATE KEY-----`까지 전체 값을 등록한다.

## 4. 배포 순서

DB 마이그레이션을 먼저 배포한다.

```powershell
npx supabase db push
```

그다음 현재 사용하는 Edge Function을 배포한다. Database Webhook과 예약 호출이 custom secret 헤더로 인증하므로 JWT 검증은 끈다.

```powershell
npx supabase functions deploy send-story-loop-notification --no-verify-jwt
npx supabase functions deploy send-answer-complete-notification --no-verify-jwt
npx supabase functions deploy send-recording-notification --no-verify-jwt
npx supabase functions deploy send-couple-disconnect-notification --no-verify-jwt
npx supabase functions deploy dispatch-scheduled-notifications --no-verify-jwt
npx supabase functions deploy send-app-notification --no-verify-jwt
```

## 5. Database Webhook 설정

각 Webhook은 Supabase Dashboard에서 아래 계약으로 설정한다.

| Table | Event | Function | Header |
| --- | --- | --- | --- |
| `public.story_loop_notification_events` | `INSERT` | `send-story-loop-notification` | `x-story-loop-webhook-secret` |
| `public.daily_question_answers` | `INSERT` | `send-answer-complete-notification` | `x-answer-webhook-secret` |
| `public.recording_notification_events` | `INSERT` | `send-recording-notification` | `x-recording-webhook-secret` |
| `public.couples` | `UPDATE` | `send-couple-disconnect-notification` | `x-couple-webhook-secret` |
| `public.app_notification_events` | `INSERT` | `send-app-notification` | `x-app-notification-webhook-secret` |

각 헤더 값은 대응하는 Edge Function secret과 같아야 한다. Webhook의 target은 표에 적힌 Edge Function이며 HTTP method는 `POST`다.

## 6. 예약 알림 설정

`dispatch-scheduled-notifications`는 스케줄러가 `POST`로 호출하고 아래 헤더를 보낸다.

```text
x-schedule-webhook-secret: <SCHEDULE_WEBHOOK_SECRET>
```

현재 예약 경로는 질문 생성 후 아직 답변하지 않은 사용자의 리마인드를 처리한다.

## 7. 동작 흐름

1. DB 쓰기 RPC가 알림 이벤트 행을 생성하거나 대상 행을 변경한다.
2. Database Webhook 또는 스케줄러가 대응 Edge Function을 호출한다.
3. Edge Function이 수신자의 알림 설정과 활성 `user_push_tokens`를 조회한다.
4. FCM HTTP v1 API로 푸시를 발송한다.
5. 무효 토큰은 비활성화한다.
6. 디스패치와 전송 결과를 `push_notification_dispatches`, `push_notification_deliveries`에 기록한다.

Android 알림 채널 ID는 앱과 Edge Function 모두 `vinscent_notifications`를 사용한다.

## 8. 검증 체크리스트

- 앱 로그인 후 `user_push_tokens` 행이 생성된다.
- 로그아웃하면 현재 기기 토큰의 `is_active`가 `false`가 된다.
- 스토리 카드, 질문 답변, 녹음, 연결 해제 이벤트가 각각 올바른 Webhook을 호출한다.
- 수신자가 해당 알림을 끄면 delivery status가 `skipped`로 기록된다.
- 활성 토큰이 없을 때도 delivery status가 `skipped`로 기록된다.
- 성공 또는 실패 결과가 `push_notification_deliveries`에 기록된다.
- 동일 이벤트 재호출은 중복 푸시를 발송하지 않는다.

## 10. 앱 활동 알림

`app_notification_events` Webhook은 다음 알림을 한 경로로 처리한다.

- 커플 연결 후 초기 설정 시작 및 완료
- 커플 캐릭터 변경
- 보관 중인 커플의 재연결 완료
- 질문 답변에 대한 캐릭터의 한마디 준비
- 24개 기초 질문 이후 기억 검토 준비
- 양쪽 검토가 끝난 뒤 개인화 활성화

Webhook 생성 시 `Supabase Edge Function` 대상으로 `send-app-notification`을 선택하고 다음 Header를 추가한다.

```text
x-app-notification-webhook-secret: <APP_NOTIFICATION_WEBHOOK_SECRET>
```

설정 화면의 `커플 활동 알림`은 연결·설정·캐릭터 변경을 제어하고, `캐릭터 소식 알림`은 한마디·기억 검토·개인화 준비 알림을 제어한다.

## 9. 현재 제약

- Android 실기기 기준으로 먼저 검증한다.
- iOS 푸시는 Apple Developer Program과 macOS/Xcode 검증 환경이 준비된 뒤 확인한다.
- 푸시 알림 표시 방식은 OS 정책의 영향을 받는다. 완전히 커스텀한 화면은 별도 인앱 알림으로 구현한다.
