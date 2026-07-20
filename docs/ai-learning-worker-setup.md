# AI Learning Worker Setup

AI 학습 작업은 `process-ai-learning-jobs` Edge Function이 소량의 작업을
claim한 뒤 Gemini structured output으로 처리한다. API 키와 원문 답변은
모바일 앱으로 전달하지 않는다.

## Secrets

저장소 루트에서 다음 시크릿을 설정한다.

```powershell
npx supabase secrets set GEMINI_API_KEY=<gemini-api-key>
npx supabase secrets set AI_WORKER_SECRET=<long-random-secret>
```

`AI_WORKER_SECRET`을 별도로 설정하지 않으면 기존
`SCHEDULE_WEBHOOK_SECRET`을 사용한다. AI 작업만 독립적으로 키를 교체할 수
있도록 운영 환경에서는 전용 시크릿을 권장한다.

선택 설정은 다음과 같다.

- `GEMINI_MODEL`: 기본값 `gemini-2.5-flash-lite`
- `GEMINI_INTERACTIONS_ENDPOINT`: Gemini Interactions API 주소 교체용
- `GEMINI_TIMEOUT_MS`: 기본값 `30000`
- `AI_WORKER_MAX_BATCH_SIZE`: 기본값 `1`, 허용 범위 `1~5`

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
- Body: `{"limit":1}`

요청 범위는 1~5건이지만 실제 처리량은 `AI_WORKER_MAX_BATCH_SIZE`로 제한된다.
무료 테스트 환경에서는 공급자 요청이 몰리지 않도록 기본 1건을 유지한다. 중복
스케줄 실행이 발생해도 DB의 원자적 claim과 lease가 같은 작업의 중복 처리를
막는다.

## Privacy

모델 입력에는 실제 사용자·커플 식별자 대신 익명 참여자 키만 전달한다.
원문 질문과 답변은 실행 로그에 저장하지 않으며, 로그에는 작업 종류,
모델, 토큰 수, 지연 시간, 제한된 오류 코드, HTTP 상태, 공급자 상태와
재시도 대기 시간만 남긴다. 공급자 오류 메시지와 응답 본문은 저장하지 않는다.
