# Storage Cleanup Webhook 설정

작성일: 2026-06-29

## 1. 목적

녹음 덮어쓰기, 업로드 실패 정리, 커플 아카이브 삭제 과정에서 Storage 파일을 직접 지우지 않고 `storage_cleanup_requests`에 정리 요청을 남긴 뒤 Edge Function이 Storage API로 실제 삭제를 처리한다.

이 문서는 그 흐름이 동작하도록 Supabase에 필요한 설정을 정리한다.

## 2. 배포 대상

이번 설정은 아래 변경이 이미 로컬 repo에 반영되어 있다는 전제로 진행한다.

- `supabase/migrations/20260629002000_add_storage_cleanup_requests.sql`
- `supabase/migrations/20260629003000_redirect_storage_deletes_to_cleanup_requests.sql`
- `supabase/functions/process-storage-cleanup/index.ts`

## 3. Secret 준비

새 웹훅용 secret 하나를 만든다.

- Secret name: `STORAGE_CLEANUP_WEBHOOK_SECRET`
- Header name: `x-storage-cleanup-webhook-secret`

PowerShell에서 난수를 만들려면:

```powershell
[guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
```

생성한 값을 Supabase secret에 저장한다.

```powershell
npx supabase secrets set STORAGE_CLEANUP_WEBHOOK_SECRET=<YOUR_SECRET>
```

현재 함수 코드는 롤아웃 편의를 위해 `EXPRESSION_WEBHOOK_SECRET`도 fallback으로 받지만, 운영에서는 `STORAGE_CLEANUP_WEBHOOK_SECRET`를 따로 두는 쪽을 기준으로 잡는다.

## 4. 마이그레이션 배포

원격 프로젝트가 이미 link 되어 있는 루트에서 실행한다.

```powershell
npx supabase migration list
npx supabase db push
```

`20260629002000`, `20260629003000`가 원격에 반영되어야 한다.

## 5. Edge Function 배포

`process-storage-cleanup` 함수는 Database Webhook이 secret header로 호출하므로 JWT 검증 없이 배포한다.

```powershell
npx supabase functions deploy process-storage-cleanup --no-verify-jwt
```

배포 후 확인:

```powershell
npx supabase functions list
```

목록에 `process-storage-cleanup`이 보여야 한다.

## 6. Database Webhook 생성

Supabase Dashboard에서 Database Webhook을 추가한다.

- Table: `public.storage_cleanup_requests`
- Event: `INSERT`
- Target: Edge Function
- Function: `process-storage-cleanup`
- Method: `POST`

추가 헤더:

```text
x-storage-cleanup-webhook-secret: <STORAGE_CLEANUP_WEBHOOK_SECRET>
Content-type: application/json
```

핵심은 헤더 값이 Supabase secret에 넣은 `STORAGE_CLEANUP_WEBHOOK_SECRET`와 정확히 같아야 한다는 점이다.

## 7. 동작 확인 쿼리

현재 녹음을 한 번 저장한 뒤 다시 덮어쓰면, 이전 파일 삭제 요청이 먼저 큐에 쌓인다.

```sql
select
  id,
  bucket_id,
  object_path,
  cleanup_reason,
  status,
  last_error,
  created_at,
  processed_at
from public.storage_cleanup_requests
order by created_at desc
limit 20;
```

정상 흐름이면:

1. 새 행이 `pending`으로 생성된다.
2. Webhook이 Edge Function을 호출한다.
3. 함수가 Storage API로 파일을 지운 뒤 `completed`로 바꾼다.

실패 시에는 `failed`와 `last_error`를 확인한다.

## 8. 확인 포인트

- 첫 녹음 저장은 기존과 동일하게 성공한다.
- 두 번째 녹음으로 현재 녹음을 덮어써도 finalize RPC가 `storage.objects` 직접 삭제 오류로 실패하지 않는다.
- `discard_uploaded_couple_recording` 경로도 직접 삭제 대신 cleanup 요청을 남긴다.
- 커플 아카이브 삭제 시 녹음/캐릭터 파일이 cleanup 요청으로 전환된다.
- 실패한 요청은 `storage_cleanup_requests.last_error`에서 원인을 볼 수 있다.
