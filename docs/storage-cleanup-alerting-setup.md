# Storage cleanup 운영 경보 설정

작성일: 2026-07-30

## 책임

`monitor-storage-cleanup-health` Edge Function은 파일을 삭제하지 않는다.
`process-storage-cleanup`의 DB 큐와 예약 실행 상태를 평가하고, 상태 전이로
생성된 운영 경보를 Discord에 전달한다.

다음 상태를 5분마다 확인한다.

- `failed`: 최대 재시도를 소진한 정리 요청이 한 건 이상 있음
- `stale_processing`: 10분 이상 `processing`에 머문 요청이 있음
- `overdue_pending`: 실행 가능한 상태로 60분 이상 남은 `pending` 요청이 있음
- 정리 Cron `process-storage-cleanup-backlog`이 없거나, 중복되거나,
  비활성화되거나, `*/5 * * * *` 주기와 다름
- 정리 Cron의 최근 성공이 없거나 15분보다 오래됨

정상에서 이상으로 바뀔 때 한 번, 감지 항목의 조합이 달라질 때 한 번,
다시 정상으로 돌아올 때 한 번만 경보를 만든다. 동일한 감지 항목에서 요청
개수만 달라지는 경우에는 중복 경보를 만들지 않는다.

Discord에는 허용된 상태 코드, 집계 개수, 감지 시각만 전달한다. 사용자 ID,
커플 ID, Storage 경로, 오류 원문은 전달하지 않는다.

## 배포 순서

프로젝트 루트에서 DB 경계를 먼저 배포한다.

```powershell
npx.cmd supabase db push
```

적용 대상에
`20260730003000_add_storage_cleanup_operational_alerts.sql`이 포함되어야 한다.

이후 모니터 함수를 배포한다.

```powershell
npx.cmd supabase functions deploy monitor-storage-cleanup-health --no-verify-jwt
```

`--no-verify-jwt`는 공개 호출을 허용하지 않는다. 함수가
`x-storage-cleanup-alert-worker-secret`을 직접 검증하며, 전용 값이 없을 때만
`x-schedule-webhook-secret`을 허용한다.

## Secret

필수 Edge secret:

- `OPERATIONS_DISCORD_WEBHOOK_URL`: Discord Incoming Webhook 전체 URL
- `STORAGE_CLEANUP_ALERT_WORKER_SECRET`: 예약 호출 전용 비밀값

선택 Edge secret:

- `STORAGE_CLEANUP_ALERT_WORKER_MAX_BATCH_SIZE`: 호출당 최대 경보 수,
  기본값 20, 허용 범위 1~100

Webhook URL은 토큰을 포함한 자격 증명이다. 명령 이력과 문서에 값을 직접
적지 않고 Git에서 제외된 환경 파일로 등록한다.

```powershell
npx.cmd supabase secrets set --env-file <ignored-production-env-file>
```

Discord Webhook 실행에는 `wait=true`를 강제해 메시지가 저장되었는지 확인한다.
429 응답은 `Retry-After`를 우선 사용하고, 네트워크 오류와 5xx 응답은 지수
백오프로 최대 5회 재시도한다. 4xx 거부는 잘못된 주소나 폐기된 Webhook으로
보고 즉시 실패 처리한다.

## Cron

Supabase Vault에 다음 두 값을 준비한다.

- `project_url`: `https://<project-ref>.supabase.co`
- `storage_cleanup_alert_worker_secret`:
  `STORAGE_CLEANUP_ALERT_WORKER_SECRET`과 같은 값

Supabase Cron에 HTTP 작업을 하나 추가한다.

- 이름: `monitor-storage-cleanup-health`
- 주기: `*/5 * * * *`
- 메서드: `POST`
- URL:
  `https://<project-ref>.supabase.co/functions/v1/monitor-storage-cleanup-health`
- 헤더:
  `x-storage-cleanup-alert-worker-secret: <worker-secret>`
- 헤더: `content-type: application/json`
- 본문: `{"limit":20}`
- HTTP timeout: 30초 이상

Secret 값은 Cron SQL이나 SQL Editor 결과에 평문으로 남기지 않고 Vault에서
읽는다. 원격 리소스 구성 후
`supabase/snippets/audit_edge_runtime_resources.sql`의 Cron 결과가
`ready`인지 확인한다.

## 수동 검증

함수를 직접 한 번 호출한다.

```powershell
$secret = '<STORAGE_CLEANUP_ALERT_WORKER_SECRET>'
$projectUrl = 'https://<project-ref>.supabase.co'

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "$projectUrl/functions/v1/monitor-storage-cleanup-health" `
  -Headers @{
    'x-storage-cleanup-alert-worker-secret' = $secret
  } `
  -ContentType 'application/json' `
  -Body '{"limit":20}'

$response
```

정상 예시:

```json
{
  "healthStatus": "healthy",
  "issueCodes": [],
  "queued": 0,
  "claimed": 0,
  "delivered": 0,
  "retried": 0,
  "failed": 0,
  "stale": 0
}
```

현재 상태는 다음 쿼리로 확인한다.

```sql
select
  status,
  issue_codes,
  failed_request_count,
  stale_processing_count,
  overdue_pending_count,
  cleanup_cron_status,
  cleanup_cron_last_succeeded_at,
  last_evaluated_at,
  last_changed_at
from public.storage_cleanup_health_state
where monitor_key = 'storage_cleanup';
```

최근 경보 전송 상태는 다음 쿼리로 확인한다.

```sql
select
  alert_kind,
  issue_codes,
  status,
  attempt_count,
  last_error,
  detected_at,
  delivered_at
from public.storage_cleanup_operational_alerts
order by created_at desc
limit 20;
```

## 감시 한계

정리 작업과 모니터는 서로 다른 Cron 작업이므로 모니터가 실행되는 동안에는
정리 Cron의 누락, 비활성, 주기 오류, 장기 실패를 감지할 수 있다. 다만
Supabase `pg_cron` 자체가 완전히 멈추면 모니터 Cron도 실행되지 않는다.
출시 후에는 외부 가용성 감시에서 모니터 함수 또는 별도 heartbeat를 확인해야
이 장애까지 감지할 수 있다.

## 공식 근거

- Supabase Cron:
  https://supabase.com/docs/guides/cron
- Supabase Edge Function secrets:
  https://supabase.com/docs/guides/functions/secrets
- Discord Execute Webhook:
  https://docs.discord.com/developers/resources/webhook#execute-webhook
- Discord rate limits:
  https://docs.discord.com/developers/topics/rate-limits
