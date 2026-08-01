# AI Learning Worker Setup

AI 학습 작업은 `process-ai-learning-jobs` Edge Function이 소량의 작업을
claim한 뒤 Cloudflare Workers AI의 Qwen3 structured output으로 처리한다.
API 토큰과 원문 답변은 모바일 앱으로 전달하지 않는다.

## Secrets

저장소 루트에서 다음 시크릿을 설정한다.

```powershell
npx supabase secrets set CLOUDFLARE_ACCOUNT_ID=<cloudflare-account-id>
npx supabase secrets set CLOUDFLARE_WORKERS_AI_API_TOKEN=<workers-ai-api-token>
npx supabase secrets set AI_WORKER_SECRET=<long-random-secret>
```

`AI_WORKER_SECRET`을 별도로 설정하지 않으면 기존
`SCHEDULE_WEBHOOK_SECRET`을 사용한다. AI 작업만 독립적으로 키를 교체할 수
있도록 운영 환경에서는 전용 시크릿을 권장한다.

선택 설정은 다음과 같다.

- `CLOUDFLARE_WORKERS_AI_MODEL`: 기본값 `@cf/qwen/qwen3-30b-a3b-fp8`
- `CLOUDFLARE_WORKERS_AI_TIMEOUT_MS`: 학습 작업 호출 제한 시간, 기본값 `30000`
- `AI_WORKER_MAX_BATCH_SIZE`: 기본값 `3`, 허용 범위 `1~5`

## Deploy

저장소 루트에서 DB 경계와 Edge Function을 배포한다.

```powershell
npx supabase db push
npx supabase functions deploy process-ai-learning-jobs --no-verify-jwt
```

`--no-verify-jwt`는 공개 호출을 허용한다는 뜻이 아니다. 함수가
`x-ai-worker-secret` 또는 정확한 service-role Bearer 토큰을 상수 시간
비교로 직접 검증한다.

## Schedule

Supabase Cron에서 1분 간격 HTTP 작업을 만들고 다음 요청을 보낸다.

- Method: `POST`
- URL: `https://<project-ref>.supabase.co/functions/v1/process-ai-learning-jobs`
- Header: `x-ai-worker-secret: <AI_WORKER_SECRET 또는 SCHEDULE_WEBHOOK_SECRET>`
- Header: `content-type: application/json`
- Body: `{"limit":3}`

요청 범위는 1~5건이지만 실제 처리량은 `AI_WORKER_MAX_BATCH_SIZE`로 제한된다.
한 질문이 완료될 때 생성되는 사용자 피드백, 다음 질문 준비, 기억 추출을 한 번의
호출에서 순차 처리할 수 있도록 기본값은 3건이다. 공급자 제한이 낮은 환경에서는
시크릿과 Cron 요청의 값을 함께 낮춘다. 중복 스케줄 실행이 발생해도 DB의 원자적
claim과 lease가 같은 작업의 중복 처리를 막는다.

준비된 작업은 프로필 재구축, 사용자 피드백, 다음 질문 준비, 기억 추출 순으로
처리한다. 같은 종류 안에서는 재시도 가능 시각과 생성 시각이 빠른 작업을 먼저
처리한다.

## Privacy

모델 입력에는 실제 사용자·커플 식별자 대신 익명 참여자 키만 전달한다.
원문 질문과 답변은 실행 로그에 저장하지 않으며, 로그에는 작업 종류,
모델, 토큰 수, 지연 시간, 제한된 오류 코드, HTTP 상태, 공급자 상태와
재시도 대기 시간만 남긴다. 공급자 오류 메시지와 응답 본문은 저장하지 않는다.
Cloudflare Workers AI는 명시적인 동의 없이 고객 입력과 생성 결과를 모델
학습이나 Cloudflare·제3자 서비스 개선에 사용하지 않는다고 밝히고 있다.

## Feature Entitlements

`public.ai_feature_entitlements`는 결제 내역이 아니라 기능 접근 권한만 관리한다.
앱 사용자는 원본 테이블을 직접 읽거나 수정할 수 없고, 활성 상태이면서 만료되지
않은 기능 키만 AI 대시보드 응답으로 받는다.

개발 환경에서 집중 질문 기능을 열 때는 SQL Editor에서 대상 커플에 다음 권한을
부여한다.

```sql
insert into public.ai_feature_entitlements (
  couple_id,
  feature_key,
  source,
  is_enabled
)
values (
  '<couple-id>',
  'focused_questions',
  'development',
  true
)
on conflict (couple_id, feature_key)
do update set
  source = excluded.source,
  is_enabled = true,
  expires_at = null;
```

추후 결제를 붙일 때 영수증과 구독 상태는 별도 결제 경계에서 검증하고, 검증된
결과만 이 테이블의 기능 권한으로 반영한다.
