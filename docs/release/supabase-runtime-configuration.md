# Supabase 런타임 설정 기준

이 문서는 단짠의 Supabase Edge Function을 새 프로젝트나 복구 환경에서
동일하게 구성하기 위한 기준이다. 실제 값은 저장소에 기록하지 않고,
필요한 환경변수 이름과 사용 함수는
`supabase/runtime-environment.manifest.json`에서 관리한다.

## 자동 검증

```powershell
node scripts/verify_supabase_runtime_environment.mjs
```

검증기는 다음 계약을 확인한다.

- Edge Function 코드가 참조하는 모든 환경변수가 매니페스트에 존재한다.
- 더 이상 코드에서 사용하지 않는 항목이 매니페스트에 남지 않는다.
- 공유 모듈의 간접 사용까지 실제 함수 목록과 일치한다.
- 항목과 함수 목록이 중복 없이 정렬되어 있다.
- 실제 비밀값을 담을 수 있는 임의 필드가 매니페스트에 추가되지 않는다.

이 검증은 `node scripts/test_supabase_functions.mjs`에도 포함되어 CI에서
항상 실행된다.

## 항목 의미

| 필드 | 의미 |
| --- | --- |
| `availability: required` | 해당 기능을 운영하려면 반드시 구성해야 한다. |
| `availability: optional` | 코드 기본값이 있거나 부가 기능에만 사용한다. |
| `availability: fallback` | 전용 값이 없으면 `fallbackTo` 값을 사용한다. |
| `provisioning: supabase_platform` | Supabase가 함수 런타임에 기본 제공한다. |
| `provisioning: supabase_secret` | Dashboard 또는 CLI로 운영자가 등록한다. |
| `sensitivity: secret` | 외부 공개, 로그, 저장소 커밋을 금지한다. |
| `sensitivity: configuration` | 값 자체는 자격 증명이 아니지만 환경별로 관리한다. |

`SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY`는 현재 코드가 사용하는
Supabase 기본 제공 값이다. `SUPABASE_SERVICE_ROLE_KEY`는 RLS를 우회하므로
클라이언트 앱이나 정책 웹에 절대 포함하지 않는다.

## 운영 환경 대조

1. 코드와 매니페스트가 일치하는지 자동 검증을 실행한다.
2. 연결된 운영 프로젝트의 등록 항목을 조회한다.
3. 매니페스트에서 `supabase_secret`인 필수 항목과 대체 항목이 운영
   프로젝트에 존재하는지 이름으로 대조한다.
4. 각 웹훅과 스케줄러가 보내는 헤더 값이 대응하는 Edge Function 값과
   일치하는지 별도의 통합 테스트로 확인한다.

```powershell
npx supabase secrets list
```

Supabase CLI의 `secrets list`는 등록 상태를 확인하는 용도다. 검증 결과,
문서, 이슈, 스크린샷에 비밀값을 붙이지 않는다. 값 변경이 필요하면 Git에
추적되지 않는 전용 환경 파일을 준비한 뒤 다음 형식으로 등록한다.

```powershell
npx supabase secrets set --env-file <ignored-production-env-file>
```

Supabase 공식 문서에 따르면 운영 secrets는 Dashboard 또는 CLI로
등록할 수 있고, 변경 후 함수를 다시 배포할 필요 없이 즉시 제공된다.

## 출시 전 별도 확인

매니페스트의 `optional`은 코드가 시작될 수 있다는 뜻이지, 상용 출시
요건이 끝났다는 뜻은 아니다.

- `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_WORKERS_AI_API_TOKEN`: Workers AI
  운영 계정과 토큰 권한을 확인하고 일일 사용량 경보를 구성한다.
- `MET_NORWAY_USER_AGENT`: 서비스명·버전과 공개 연락처를 포함한 식별값을
  등록한다. 예: `Danjjan/1.0 vinscent0929@gmail.com`.
- `MET_NORWAY_FORECAST_ENDPOINT`, `MET_NORWAY_SUNRISE_ENDPOINT`: 공식
  endpoint를 바꿔야 할 때만 등록한다. 기본값을 사용할 때는 생략한다.
- MET Norway는 API 키가 필요하지 않는다. Locationforecast와 Sunrise
  호출은 서버 프록시에서 좌표를 반올림하고 제공자 캐시 지침을 따른다.
- Apple 자격 증명 4종: Android 출시에는 필요하지 않다. Sign in with
  Apple을 제공하는 iOS 출시 전에는 네 값을 모두 등록하고 실제 Apple
  계정에서 토큰 철회 통합 테스트를 한다.
- `SAFETY_MODERATION_DISCORD_WEBHOOK_URL`: 비공개 안전 신고 채널 전용
  Discord 웹훅을 등록한다. 기존 일반 HTTPS 수신기의
  `SAFETY_MODERATION_WEBHOOK_URL`은 호환 경로로만 유지한다.
- FCM 자격 증명 3종: Android와 iOS에서 foreground, background, terminated
  상태의 수신을 각각 검증한다.
- 모든 `*_WEBHOOK_SECRET`: Dashboard 웹훅 또는 스케줄러 헤더와 함수
  환경값의 일치를 검증한다.

출시 전에는 사용자 트래픽이 없는 유지보수 구간에서 모든 전용 웹훅·스케줄
비밀값을 새 값으로 교체한다. 각 값은 Git에서 무시되는 환경 파일로 Edge
secret에 등록하고, 대응하는 Database Webhook 또는 Cron 헤더를 즉시 같은
값으로 갱신한다. 교체가 끝나면 수동 호출과 아래 원격 감사를 모두 통과한
뒤 이전 값을 폐기한다. 비밀값 자체는 명령 출력, SQL 결과, 문서에 남기지
않는다.

Database Webhook과 예약 호출의 생성 자체는 아직 Dashboard 운영
설정이다. 현재 매니페스트는 함수가 요구하는 계약을 고정하지만, 원격
웹훅 리소스를 자동 생성하지는 않는다. 이를 마이그레이션으로 옮길 때는
비밀값을 SQL이나 함수 정의에 평문으로 넣지 않고 Supabase Vault 기반
호출로 설계한다.

원격 리소스의 현재 상태는 Supabase SQL Editor에서
`supabase/snippets/audit_edge_runtime_resources.sql`을 실행해 확인한다.
이 쿼리는 웹훅 정의와 Cron 명령 원문을 반환하지 않으므로 저장된 비밀값을
노출하지 않는다. 두 결과의 `audit_status`가 모두 `ready`여야 하며,
archive purge는 운영 주기를 확정하기 전까지
`cadence_decision_required`로 표시된다.

`supabase/.temp`에는 원격 카탈로그 캐시가 저장되며 운영 설정 일부가
포함될 수 있다. 이 경로는 Git에서 무시되지만 외부 공유 파일이나 빌드
산출물에 포함하지 않는다.

Database migration과 Edge Function의 승인된 운영 배포는
`.github/workflows/supabase-production.yml`을 사용한다. 이 workflow는
secret 값을 등록하거나 Database Webhook·Cron을 바꾸지 않으며, 실행
방법과 복구 원칙은
`docs/release/supabase-production-deployment.md`를 따른다.

## 공식 근거

- Supabase Edge Function 환경변수와 운영 secrets:
  https://supabase.com/docs/guides/functions/secrets
- Supabase CLI secrets 명령:
  https://supabase.com/docs/reference/cli/supabase-secrets
- Vault를 이용한 예약 Edge Function 호출:
  https://supabase.com/docs/guides/functions/schedule-functions
- MET Norway API 이용 조건:
  https://api.met.no/doc/TermsOfService
- MET Norway 데이터 라이선스:
  https://api.met.no/doc/License
