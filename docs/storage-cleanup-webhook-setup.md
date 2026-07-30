# Storage cleanup worker setup

작성일: 2026-07-30

## 목적

앱의 DB 트랜잭션에서는 Storage 파일을 직접 삭제하지 않는다. 카드, 캐릭터,
녹음, 녹음 슬롯 그림, 일정 그림에서 더 이상 참조하지 않는 파일은
`storage_cleanup_requests`에 기록하고 `process-storage-cleanup` Edge Function이
Storage API로 삭제한다.

정리 함수는 두 경로를 함께 지원한다.

- Database Webhook: 새 요청 한 건을 즉시 처리한다.
- 예약 배치: Webhook 실패, 일시 장애, 과거 누락으로 남은 요청을 복구한다.

예약 배치는 Storage에 올라온 지 60분이 지난 파일만 고아 여부를 검사한다.
삭제 직전에도 현재 DB 참조를 다시 확인하므로 저장 중인 파일이나 다시 참조된
파일은 삭제하지 않는다.

## 배포

프로젝트 루트에서 마이그레이션을 먼저 적용한다.

```powershell
npx.cmd supabase db push
```

적용 대상 마이그레이션에
`20260730002000_recover_storage_cleanup_backlogs.sql`이 포함되어야 한다.

이후 Edge Function을 배포한다.

```powershell
npx.cmd supabase functions deploy process-storage-cleanup --no-verify-jwt
```

기존 `STORAGE_CLEANUP_WEBHOOK_SECRET`은 그대로 사용한다. 값이 없다면 생성해서
등록한다.

```powershell
$secret = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
npx.cmd supabase secrets set STORAGE_CLEANUP_WEBHOOK_SECRET=$secret
```

## Database Webhook

Supabase Dashboard의 Database Webhooks에서 다음 설정을 유지한다.

- 이름: `process-storage-cleanup`
- 테이블: `public.storage_cleanup_requests`
- 이벤트: `INSERT`
- 대상: Edge Function
- 함수: `process-storage-cleanup`
- 메서드: `POST`
- 헤더:
  `x-storage-cleanup-webhook-secret: <STORAGE_CLEANUP_WEBHOOK_SECRET>`

이 Webhook은 새 요청의 지연을 줄인다. Webhook이 실패해도 요청은 DB에 남고
예약 배치가 다시 회수한다.

## 예약 배치

Supabase Cron에서 HTTP 작업을 하나 추가한다.

- 이름: `process-storage-cleanup-backlog`
- 주기: `*/5 * * * *`
- 메서드: `POST`
- URL:
  `https://<project-ref>.supabase.co/functions/v1/process-storage-cleanup`
- 헤더:
  `x-storage-cleanup-webhook-secret: <STORAGE_CLEANUP_WEBHOOK_SECRET>`
- 헤더: `content-type: application/json`
- 본문: `{"limit":20,"reconcileLimit":100}`

한 번의 호출은 다음 순서로 동작한다.

1. 60분 이상 지난 Storage 파일 중 DB 참조가 없는 파일을 최대 100개 찾는다.
2. 누락된 정리 요청을 생성한다.
3. 기존 pending 요청과 새 요청을 합쳐 최대 20개 claim한다.
4. 삭제 직전 참조 여부를 다시 확인한다.
5. 일시 실패는 최대 5회까지 지수 백오프로 재시도한다.
6. 중단된 processing claim은 5분 뒤 다른 실행이 회수한다.

## 수동 검증

예약 배치와 같은 요청을 PowerShell에서 한 번 실행할 수 있다.

```powershell
$secret = '<STORAGE_CLEANUP_WEBHOOK_SECRET>'
$projectUrl = 'https://<project-ref>.supabase.co'

$response = Invoke-RestMethod `
  -Method Post `
  -Uri "$projectUrl/functions/v1/process-storage-cleanup" `
  -Headers @{ 'x-storage-cleanup-webhook-secret' = $secret } `
  -ContentType 'application/json' `
  -Body '{"limit":20,"reconcileLimit":100}'

$response
```

응답 예시는 다음과 같다.

```json
{
  "reconciled": 24,
  "claimed": 20,
  "deleted": 20,
  "preserved": 0,
  "retried": 0,
  "failed": 0,
  "stale": 0
}
```

현재 상태는 다음 쿼리로 확인한다.

```sql
select
  status,
  completion_outcome,
  count(*) as request_count,
  pg_size_pretty(
    coalesce(sum((object.metadata ->> 'size')::bigint), 0)
  ) as storage_size
from public.storage_cleanup_requests as request
left join storage.objects as object
  on object.bucket_id = request.bucket_id
  and object.name = request.object_path
group by status, completion_outcome
order by status, completion_outcome;
```

재시도 중인 요청은 다음 쿼리로 확인한다.

```sql
select
  id,
  bucket_id,
  object_path,
  status,
  attempt_count,
  max_attempts,
  available_at,
  last_error,
  created_at
from public.storage_cleanup_requests
where status in ('pending', 'processing', 'failed')
order by available_at, created_at;
```

현재 DB가 참조하는 파일은 `completion_outcome = 'still_referenced'`로 완료되며
Storage에서 보존된다. 같은 경로가 나중에 실제 고아가 되면 새 요청을 만들 수
있다.

## 기존 누적 데이터

이 마이그레이션과 함수를 배포한 뒤 예약 배치를 호출하면 기존의 pending 요청도
오래된 순서대로 처리한다. 요청이 없던 과거 고아 파일도 60분 안전 유예를 통과한
뒤 자동으로 발견한다.

`storage.objects`를 직접 DELETE하거나 서비스 역할 키로 파일 목록을 반복 삭제할
필요가 없다. 직접 삭제는 현재 참조 재검증과 재시도 기록을 우회하므로 사용하지
않는다.
