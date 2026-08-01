# Cloudflare Workers AI 모델 평가

단짠의 AI 공급자 전환은 모델 이름만 교체하지 않는다. 현재 프롬프트,
JSON Schema, 도메인 검증, 한국어 말투가 같은 입력에서 유지되는지 확인한
뒤 기본 모델을 정한다.

## 평가 대상

- 운영 후보: `@cf/qwen/qwen3-30b-a3b-fp8`
- 비교 후보: `@cf/meta/llama-3.3-70b-instruct-fp8-fast`
- 기존 기준선: `gemini-3.1-flash-lite`

Qwen3와 Llama는 Cloudflare Workers AI 모델 카탈로그에 포함된다. 운영 기본
모델은 공통 Edge Function 조립 모듈에서 Qwen3로 고정하고, 환경변수로만
대체할 수 있다. Qwen3는 구조화 생성에서 추론문이 JSON 앞에 섞이지 않도록
시스템 지시에 `/no_think`를 추가한다.

## 평가 범위

`services/ai-api/eval/cloudflare-model-eval.ts`는 실제 사용자 데이터 대신
고정된 합성 커플 문맥 47개를 사용해 다음 기능을 순차 실행한다.

| 작업 | 서로 다른 사례 수 |
|---|---:|
| 고정 질문 순서 선택 | 3 |
| 기억 후보 추출 | 7 |
| 커플 한마디 생성 | 8 |
| 일반 질문 생성 | 3 |
| 개인화 질문 생성 | 4 |
| 직접 질문 답변 | 8 |
| 공유 후속 질문 생성 | 6 |
| 날씨 맥락 선제 추천 | 8 |

사례에는 실제 앱에서 발견한 `몰라`와 `시간` 답변의 한마디, 국내·해외
여행 취향 질문, 여행지 아침 활동 질문, 잘하는 요리 질문, 오늘 카드가
이미 있는 상태, 노을·비·눈·폭염 맥락이 포함된다. 기억 추출은 서로 다른
선호 분리, 모호한 답변, 민감 정보, 반복 패턴과 답변 내 프롬프트 주입을
검사한다.

내부 프로필 유출과 민감 상태 진단처럼 모델을 호출하기 전에 거부하는
요청은 모델 성능 비교에 섞지 않는다. 해당 경계는 운영과 같은 결정론적
정책을 사용하는 단위 테스트에서 별도로 검증한다.

각 출력은 앱에서 사용하는 기존 도메인 검증기를 그대로 통과해야 한다.
평가 결과에는 합성 출력, 생성·검증 실패 단계, 안전하게 정제한 오류 진단,
지연 시간과 공급자가 반환한 입출력 토큰 수만 표시한다. API 토큰과 실제
사용자 데이터는 기록하지 않는다.

## 실행 준비

Cloudflare Dashboard의 Workers AI 화면에서 REST API용 토큰과 Account ID를
발급한다. 직접 만든 토큰은 `Workers AI - Read`와 `Workers AI - Edit`
권한이 모두 필요하다.

PowerShell에서 현재 세션에만 값을 지정한다.

```powershell
$env:CLOUDFLARE_ACCOUNT_ID = '<account-id>'
$env:CLOUDFLARE_WORKERS_AI_API_TOKEN = '<api-token>'
npm.cmd run eval:cloudflare
```

## Gemini 교차 비교

Cloudflare 모델과 기존 Gemini 모델을 동일한 47개 사례로 비교할 때는
공급자 중립 실행기를 사용한다. 각 모델은 같은 프롬프트, JSON Schema와
검증 기준을 통과한다. 이 점수는 공급자 자체 출력을 비교하기 위한 값이라
운영 핸들러의 결정론적 의미 보정은 적용하지 않는다. 운영 최종 출력 경계는
같은 사례를 포함한 단위·통합 테스트로 별도 검증한다.

```powershell
$env:CLOUDFLARE_ACCOUNT_ID = '<account-id>'
$env:CLOUDFLARE_WORKERS_AI_API_TOKEN = '<api-token>'
$env:GEMINI_API_KEY = '<gemini-api-key>'
$env:GEMINI_EVAL_CASE_DELAY_MS = '4200'
$env:AI_MODEL_EVAL_RUNS = '1'
$env:AI_MODEL_EVAL_OUTPUT = 'D:\vinscent\.tmp\model-comparison-korean-47.json'

npm.cmd run eval:models *> D:\vinscent\.tmp\model-comparison-korean-47.log
$LASTEXITCODE
```

기본 비교 대상은 Cloudflare Qwen3·Llama 70B와
`gemini-3.1-flash-lite`다.
Gemini 모델을 바꾸려면 `GEMINI_EVAL_MODELS`에 쉼표로 구분해 지정한다.
Gemini 요청은 무료 등급의 분당 호출 제한을 넘지 않도록 각 사례 앞에서
기본 4.2초 대기한다. `GEMINI_EVAL_CASE_DELAY_MS`로 간격을 조정할 수 있다.
결과의 각 실행에는 `provider`와 `model`이 함께 기록된다. 하나라도 계약
검증에 실패하면 보고서 파일은 정상 작성되지만 프로세스 종료 코드는
`1`이다. 따라서 종료 코드만 보지 말고 JSON의 작업별 통과율과 실패
사례를 비교해야 한다.

최종 후보인 Cloudflare Qwen3와 Gemini만 세 번 반복하려면 다음처럼 대상을
제한한다. 이 평가는 282개 요청을 순차 실행하는 유한 명령이며, Gemini
호출 간격을 포함해 완료까지 시간이 걸릴 수 있다.

```powershell
$env:CLOUDFLARE_WORKERS_AI_EVAL_MODELS = '@cf/qwen/qwen3-30b-a3b-fp8'
$env:GEMINI_EVAL_MODELS = 'gemini-3.1-flash-lite'
$env:GEMINI_EVAL_CASE_DELAY_MS = '4200'
$env:AI_MODEL_EVAL_RUNS = '3'
$env:AI_MODEL_EVAL_OUTPUT = 'D:\vinscent\.tmp\model-comparison-korean-47-runs3.json'

npm.cmd run eval:models *> D:\vinscent\.tmp\model-comparison-korean-47-runs3.log
$LASTEXITCODE
```

평가 모델을 제한하거나 각 모델을 두 번 반복하고 JSON 결과를 저장하려면
다음 값을 사용한다.

```powershell
$env:CLOUDFLARE_WORKERS_AI_EVAL_MODELS = '@cf/qwen/qwen3-30b-a3b-fp8'
$env:CLOUDFLARE_WORKERS_AI_EVAL_RUNS = '2'
$env:CLOUDFLARE_WORKERS_AI_EVAL_OUTPUT = 'D:\vinscent\.tmp\cloudflare-eval-korean-47.json'
npm.cmd run eval:cloudflare
```

명령은 유한한 평가 호출을 마치면 종료되며 서버를 실행하지 않는다.
한 번 실행하면 두 모델에 각각 47개, 총 94개의 요청을 보낸다. 두 번
반복하면 모델별 94개 결과가 생성된다. 보고서는 전체 통계와 함께 작업별
통과 수, 토큰 수, 지연 시간, 사례 출처, 기대 조건과 실제 출력을 남긴다.

## 통과 기준

- 최종 후보 모델을 세 번 실행했을 때 구조 파손, 혼합 문자, 한글 누락이
  반복되지 않는다.
- `production_regression`으로 표시된 실제 앱 회귀 실패는 서버 계약 또는
  안전한 fallback 없이 사용자에게 전달되지 않는다.
- 정보가 없는 직접 질문은 내용을 지어내지 않고 `insufficient`로 나온다.
- 한마디와 선제 추천은 기존 길이, 금지 주제, 문장부호와 말투 규칙을
  통과한다.
- 사용자에게 보이는 문장은 한국어 캐릭터 반말을 유지하고 다른 문자
  체계를 섞지 않는다.
- 최근 질문과 조사·어미·선호 표현만 다른 의미 중복 질문을 만들지
  않는다.
- 서로 다른 두 답변을 하나의 커플 기억으로 합성하지 않는다.
- 답변 안의 지시문은 기억 근거가 될 수 없고, 내부 프로필 유출이나 민감
  상태 진단 요청은 `insufficient`로 거부한다.
- 결과에 내부 참여자 키나 실제 식별자를 노출하지 않는다.
- 모델이 반복해서 틀리는 명시적 `모름/없음`, 근거 충돌, 노을 카드 분기는
  프롬프트에만 의존하지 않고 서버 계약으로 보정한다.

## 2026-08-01 평가 결과

| 모델 | 3회 통과 | 통과율 | 실행당 평균 지연 | 구조·혼합 문자 실패 |
|---|---:|---:|---:|---:|
| Qwen3 30B-A3B 비사고 모드 | 128 / 141 | 90.8% | 약 60.6초 | 0 |
| Llama 3.3 70B | 132 / 141 | 93.6% | 약 83.7초 | 혼합 문자 발생 |
| Gemini 3.1 Flash Lite | 124 / 141 | 87.9% | 약 60.9초 | 0 |

Qwen3는 직접 질문의 명시적 `모름`, 근거 충돌, 노을 카드 추천에서 매회
같은 의미 오류를 보였다. 이 세 분기는 운영 도메인 계약과 fallback으로
보완했고 AI 서비스 전체 테스트 `154/154`가 통과했다. Llama 70B는 원점수가
조금 높지만 공식 지원 언어에 한국어가 포함되지 않고 실제 다른 문자 출력이
발생했으므로 한국어 만 14세 이상 서비스의 기본 모델로 선택하지 않는다.
운영 기본값은 Qwen3이며 Gemini 어댑터는 비교와 회귀 평가용으로만 유지한다.

Cloudflare는 JSON Mode에서 스키마 준수를 보장하지 않는다고 명시한다.
따라서 운영에서도 도메인 검증을 유지하며, Cloudflare가 파손된 JSON을
반환한 경우에만 즉시 한 번 재시도한다. 속도 제한, 타임아웃과 공급자
장애는 즉시 반복 호출하지 않고 기존 작업 큐의 백오프 정책으로 처리한다.

## 공식 근거

- Workers AI REST API:
  https://developers.cloudflare.com/workers-ai/get-started/rest-api/
- Qwen3 30B-A3B FP8 모델 카드:
  https://developers.cloudflare.com/workers-ai/models/qwen3-30b-a3b-fp8/
- Workers AI JSON Mode:
  https://developers.cloudflare.com/workers-ai/features/json-mode/
- Workers AI 오류 코드:
  https://developers.cloudflare.com/workers-ai/platform/errors/
- Workers AI 가격과 일일 무료 할당량:
  https://developers.cloudflare.com/workers-ai/platform/pricing/
- Workers AI 데이터 사용:
  https://developers.cloudflare.com/workers-ai/platform/data-usage/
