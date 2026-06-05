# 표현 푸시 알림 설정

작성일: 2026-06-05

## 1. 기준 프로젝트

새 Supabase 프로젝트를 만들지 않는다.

현재 모바일 앱이 `SUPABASE_URL`, `SUPABASE_ANON_KEY`로 연결하는 기존 Supabase 프로젝트를 그대로 사용한다. 로컬 repo를 원격 프로젝트에 연결할 때는 Supabase Dashboard의 Project ID를 사용한다.

```powershell
npx supabase login
npx supabase link --project-ref <SUPABASE_PROJECT_ID>
npx supabase migration list
```

마이그레이션 이력이 원격 DB 상태와 맞는지 확인한 뒤에만 `db push`를 실행한다.

## 2. Firebase 준비

Firebase 프로젝트에 Android 앱과 iOS 앱을 각각 등록한다.

- Android package name: `com.vinscent.vinscent`
- iOS bundle id: `com.vinscent.vinscent`

필요 파일:

- `apps/mobile/android/app/google-services.json`
- `apps/mobile/ios/Runner/GoogleService-Info.plist`

iOS 푸시는 Apple Developer 계정, Push Notifications capability, APNs Auth Key 등록이 필요하다. Apple Developer 계정이 없으면 Android 푸시부터 검증한다.

## 3. Supabase Edge Function secrets

Firebase Admin SDK 서비스 계정 JSON에서 아래 값을 가져와 Supabase Edge Function Secrets에 저장한다.

- `FCM_PROJECT_ID`: Firebase service account JSON의 `project_id`
- `FCM_CLIENT_EMAIL`: Firebase service account JSON의 `client_email`
- `FCM_PRIVATE_KEY`: Firebase service account JSON의 `private_key`
- `EXPRESSION_WEBHOOK_SECRET`: 직접 생성한 긴 랜덤 문자열

서비스 계정 JSON 파일은 Git에 커밋하지 않는다.

Secret은 Dashboard 또는 CLI로 등록할 수 있다.

```powershell
npx supabase secrets set FCM_PROJECT_ID=...
npx supabase secrets set FCM_CLIENT_EMAIL=...
npx supabase secrets set FCM_PRIVATE_KEY="..."
npx supabase secrets set EXPRESSION_WEBHOOK_SECRET=...
```

`FCM_PRIVATE_KEY`는 `-----BEGIN PRIVATE KEY-----`부터 `-----END PRIVATE KEY-----`까지 전체 값이 필요하다.

## 4. 배포 순서

DB 마이그레이션을 먼저 배포한다.

```powershell
npx supabase db push
```

그 다음 Edge Function을 배포한다. Database Webhook이 custom secret 헤더로 인증하므로 JWT 검증은 끈다.

```powershell
npx supabase functions deploy send-expression-notification --no-verify-jwt
```

## 5. Database Webhook 설정

Supabase Dashboard에서 Database Webhook을 생성한다.

- Table: `public.couple_expressions`
- Event: `INSERT`
- Target: Edge Function
- Function: `send-expression-notification`
- HTTP method: `POST`

Webhook 요청 헤더에 아래 값을 추가한다.

```text
x-expression-webhook-secret: <EXPRESSION_WEBHOOK_SECRET>
```

이 헤더 값은 Supabase Secret에 등록한 `EXPRESSION_WEBHOOK_SECRET`과 같아야 한다.

## 6. 동작 흐름

1. 사용자가 홈에서 표현 버튼을 누른다.
2. `send_couple_expression` RPC가 `couple_expressions`에 기록을 저장한다.
3. Database Webhook이 insert 이벤트를 받아 Edge Function을 호출한다.
4. Edge Function이 `receiver_user_id`의 활성 `user_push_tokens`를 조회한다.
5. FCM HTTP v1 API로 상대방 기기에 푸시를 발송한다.
6. 실패한 토큰은 비활성화하고 `push_notification_deliveries`에 결과를 기록한다.

표현 기록 저장과 푸시 발송은 분리한다. 푸시 발송 실패가 표현 기록 저장 실패로 이어지면 안 된다.

## 7. 검증 체크리스트

- 앱 실행 후 로그인한 사용자의 `user_push_tokens` 행이 생성된다.
- 로그아웃하면 현재 기기 토큰의 `is_active`가 `false`가 된다.
- 표현 버튼을 누르면 `couple_expressions` 기록이 생성된다.
- 상대방 사용자에게 활성 토큰이 있으면 푸시가 도착한다.
- 푸시 결과가 `push_notification_deliveries`에 기록된다.
- 상대방 토큰이 없으면 delivery status가 `skipped`로 기록된다.

## 8. 현재 제약

- Android 실기기 기준으로 먼저 검증한다.
- iOS 푸시는 Apple Developer Program과 macOS/Xcode 검증 환경이 준비된 뒤 확인한다.
- 푸시 알림은 OS 정책에 따라 표시 방식이 제한된다. 앱 내부의 완전한 커스텀 UI는 별도 인앱 알림으로 처리한다.
