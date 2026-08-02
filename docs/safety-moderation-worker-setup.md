# 안전 신고 운영 알림 워커 설정

`process-safety-moderation-alerts` Edge Function은
`safety_moderation_alerts`에서 신고 알림을 원자적으로 가져와 외부 운영
수신기로 전달한다. 이 워커는 신고 검토를 대신하지 않으며, 운영자가 신고를
놓치지 않도록 최소 메타데이터만 알리는 경계다.

## 외부 전송 범위

수신기로 보내는 JSON은 다음 필드만 포함한다.

```json
{
  "type": "danjjan.safety_report.created",
  "version": 1,
  "report": {
    "id": "<report-id>",
    "targetType": "<target-type>",
    "reason": "<reason>",
    "createdAt": "<reported-at>",
    "hasDetails": true,
    "hasContentSnapshot": false
  }
}
```

신고자·신고 대상 사용자·커플·콘텐츠 식별자와 상세 설명·콘텐츠 스냅샷은
외부 수신기로 보내지 않는다. 운영자는 알림의 `report.id`를 사용해 권한이
제한된 내부 검토 화면에서 원문을 확인해야 한다.

모든 요청에는 `x-danjjan-event-id: <report-id>`가 포함된다. 수신기는 이
값으로 중복 요청을 멱등 처리하고 성공적으로 접수했을 때만 2xx를 반환해야
한다.

## 환경변수

필수 설정:

- `SAFETY_MODERATION_DISCORD_WEBHOOK_URL`: 비공개 안전 신고 채널의 Discord
  웹훅 주소. 기존 일반 HTTPS 수신기를 사용하는 환경에서는
  `SAFETY_MODERATION_WEBHOOK_URL`로 대체할 수 있다.
- `SAFETY_MODERATION_WORKER_SECRET`: Cron 호출 전용 비밀값

선택 설정:

- `SAFETY_MODERATION_WEBHOOK_BEARER_TOKEN`: 수신기 인증용 Bearer 토큰
  일반 HTTPS 수신기에서만 사용한다.
- `SAFETY_MODERATION_WORKER_MAX_BATCH_SIZE`: 호출당 최대 처리량, 기본값 20,
  허용 범위 1~100

`SAFETY_MODERATION_WORKER_SECRET`이 없으면 기존
`SCHEDULE_WEBHOOK_SECRET`을 사용한다. 운영 환경에서는 다른 예약 작업과
독립적으로 회전할 수 있는 전용 값을 권장한다.

```powershell
npx supabase secrets set SAFETY_MODERATION_DISCORD_WEBHOOK_URL=<discord-webhook-url>
npx supabase secrets set SAFETY_MODERATION_WORKER_SECRET=<long-random-secret>
```

Discord URL이 등록되어 있으면 일반 HTTPS 수신기보다 우선한다. 일반
수신기를 유지할 때만 `SAFETY_MODERATION_WEBHOOK_URL`과 필요에 따라
`SAFETY_MODERATION_WEBHOOK_BEARER_TOKEN`을 등록한다. 웹훅 URL과 토큰은
저장소, SQL 결과, 로그에 남기지 않는다. Discord 알림에는 신고 원문과
사용자 식별자를 넣지 않고 신고 ID와 최소 분류 메타데이터만 보낸다.

## 배포

```powershell
npx supabase functions deploy process-safety-moderation-alerts --no-verify-jwt
```

`--no-verify-jwt`는 공개 호출을 허용한다는 의미가 아니다. 함수는
`x-safety-moderation-worker-secret`을 직접 검증하고, 전용 값이 없을 때만
`x-schedule-webhook-secret`을 대체 경계로 사용한다.

## Cron

Supabase Cron에서 다음 요청을 1분마다 실행한다.

- Schedule: `* * * * *`
- Method: `POST`
- URL:
  `https://<project-ref>.supabase.co/functions/v1/process-safety-moderation-alerts`
- Header:
  `x-safety-moderation-worker-secret: <SAFETY_MODERATION_WORKER_SECRET>`
- Header: `content-type: application/json`
- Body: `{"limit":20}`

동일 알림의 중복 처리는 DB claim 토큰이 막는다. 전달에 실패하면 1분부터
지수적으로 재시도하며, 최대 1시간 간격과 신고당 최대 시도 횟수를 적용한다.
처리 중 워커가 종료된 claim은 5분 뒤 다시 가져올 수 있다.

## 수동 확인

신고를 한 건 생성한 다음 함수를 직접 호출한다.

```powershell
$secret = '<SAFETY_MODERATION_WORKER_SECRET>'
$response = Invoke-WebRequest `
  -UseBasicParsing `
  -Method Post `
  -Uri 'https://<project-ref>.supabase.co/functions/v1/process-safety-moderation-alerts' `
  -Headers @{ 'x-safety-moderation-worker-secret' = $secret } `
  -ContentType 'application/json' `
  -Body '{"limit":1}'

$response.StatusCode
$response.Content
```

정상 응답은 다음 카운터를 반환한다.

```json
{
  "claimed": 1,
  "delivered": 1,
  "retried": 0,
  "failed": 0,
  "stale": 0
}
```

큐 상태는 SQL Editor에서 확인한다.

```sql
select
  report_id,
  status,
  attempt_count,
  max_attempts,
  available_at,
  delivered_at,
  completed_at,
  last_error,
  created_at
from public.safety_moderation_alerts
order by created_at desc
limit 20;
```

원격 Webhook과 Cron의 중복·헤더·주기는
`supabase/snippets/audit_edge_runtime_resources.sql` 결과가 모두 `ready`인지
확인한다.

## 출시 조건

함수 배포만으로 운영 신고 대응이 완성되지는 않는다. 출시 전 다음 항목을
확정하고 실제 신고로 통합 검증해야 한다.

1. HTTPS 수신 채널과 실제 수신 주소
2. 신고 검토 담당자와 부재 시 대체 담당자
3. 최초 확인·처리 목표 시간
4. 실패 알림과 장기 `pending`·`failed` 큐 감시 방법
5. 내부 검토 화면의 접근 통제와 감사 절차
