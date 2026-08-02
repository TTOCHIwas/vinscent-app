# AI 후보 모델 평가

이 평가는 운영 공급자를 바꾸지 않고 동일한 프롬프트, JSON Schema, 도메인 검증기로
후보 모델을 비교한다. 실제 사용자 데이터는 사용하지 않으며, 47개 합성 사례에는 현재
서비스의 8개 AI 작업과 운영 중 발견한 회귀 유형이 포함된다.

## 평가 대상

Cloudflare Workers AI:

- `@cf/qwen/qwen3-30b-a3b-fp8`
- `@cf/zai-org/glm-4.7-flash`
- `@cf/google/gemma-4-26b-a4b-it`
- `@cf/mistralai/mistral-small-3.1-24b-instruct`

Groq:

- `openai/gpt-oss-120b`
- `openai/gpt-oss-20b`

OpenAI Responses API:

- `gpt-5-nano`
- 비교가 필요할 때만 `gpt-5.4-nano`
- 비교가 필요할 때만 `gpt-5.6-luna`

Groq 모델은 `strict: true` JSON Schema와 `reasoning_effort: low`를 사용한다. Groq
공식 문서는 strict mode를 GPT-OSS 20B와 120B에서 지원하며 모든 필드를 required로
지정하고 object에 `additionalProperties: false`를 요구한다. 현재 서비스 schema는 이
계약을 만족한다. GPT-OSS 권장 방식에 맞춰 Groq 어댑터에서 시스템 지시와 사용자 요청을
하나의 user 메시지로 합치되 지시 내용은 변경하지 않는다.

OpenAI 모델은 Responses API의 strict JSON Schema를 사용하고 응답 저장은 끈다. 기본
후보인 `gpt-5-nano`에는 지원되는 가장 낮은 추론 강도인 `minimal`을 사용한다. GPT-5.4와
GPT-5.6 계열을 별도로 지정하면 기본값은 `none`이다. 추론이 켜진 설정에서는 공급자
호환성을 위해 temperature를 전송하지 않는다. 무료 API 호출을 지원하지 않으므로 계정의
결제 및 사용 한도를 확인한 뒤 실행한다.

현재 OpenAI 연결은 후보 평가 전용이다. 만 14세 이상 사용자를 대상으로 운영에 채택하려면
OpenAI의 Under 18 API Guidance에 따라 연령에 맞는 고지, 민감 콘텐츠 보호, 모니터링과
고위험 상황의 대응 경로를 별도로 검증해야 한다.

## 2026-08-02 베타 운영 결정

최종 비교에서는 Cloudflare Mistral Small 3.1 24B가 47개 사례 중 첫 응답
44개, 한 번의 모델 재시도 포함 45개, 검증된 안전 대체 문구 포함 46개를
제공했다. GPT-5 nano low는 같은 기준에서 각각 37개, 40개, 42개였다.
총 지연 시간도 Mistral 약 96.9초, GPT-5 nano 약 321.0초로 차이가 났다.

Mistral의 별도 3회 안정성 평가에서는 첫 응답 131/141, 모델 재시도 포함
134/141을 기록했다. 베타 운영 기본 모델은 다음 값으로 정한다.

```text
@cf/mistralai/mistral-small-3.1-24b-instruct
```

이 결정은 공급자 종속을 뜻하지 않는다. 환경변수 재정의, Qwen 전용
비사고 모드 처리, Gemini·Groq·OpenAI 평가 어댑터와 도메인 검증 경계는
그대로 유지한다. 베타 중에는 작업별 실패율, 429, 지연 시간과 안전 대체
비율을 관찰해 모델 변경 여부를 다시 판단한다.

## 실행 단계

`smoke`는 모델마다 8개 작업을 한 번씩 실행한다. 기본값이며 schema 호환성, 인증,
모델 접근 권한, 기본 한국어 계약을 먼저 확인한다.

`full`은 기존과 동일한 47개 사례를 모두 실행한다. smoke를 통과한 모델에만 사용한다.

평가 중에는 stderr에 모델, 반복, 사례 진행률이 출력된다. 최종 JSON 보고서는 지정한
경로에 저장된다. 계약 검증 실패가 하나라도 있으면 보고서는 정상 저장되지만 종료 코드는
`1`이다. 운영 재시도로 복구된 사례도 첫 응답 품질을 숨기지 않도록 종료 코드에는 최초
실패를 반영한다.

보고서의 `passed`는 추가 호출 없이 통과한 첫 응답 수다. `operationalPassed`는
한 번의 모델 재시도까지 거쳐 통과한 응답 수이며, `recovered`는 첫 응답은
실패했지만 모델 재시도로 복구된 사례 수다. `servedPassed`는 검증된 운영 안전
대체 문구까지 포함해 실제 사용자에게 제공할 수 있는 응답 수다. `fallbackRecovered`는
모델 재시도도 실패했지만 안전 대체 문구로 제공 가능해진 사례 수다. 각 사례의
`providerAttemptCount`와 `completionReason`으로 공급자 내부 재시도와 토큰 한도 종료 여부를
구분한다. 평가 전용 기대어 검사만 실패한 사례는 운영 복구나 안전 대체 대상으로 세지
않는다. 첫 응답, 모델 재시도, 최종 제공 점수는 서로 대체하지 않고 함께 판정한다.

## Cloudflare smoke 실행

```powershell
cd D:\vinscent\services\ai-api

$env:CLOUDFLARE_ACCOUNT_ID = '<account-id>'
$env:CLOUDFLARE_WORKERS_AI_API_TOKEN = '<api-token>'
$env:AI_CANDIDATE_EVAL_PROVIDERS = 'cloudflare'
$env:AI_CANDIDATE_EVAL_SUITE = 'smoke'
$env:AI_MODEL_EVAL_RUNS = '1'
$env:AI_CANDIDATE_EVAL_OUTPUT = 'D:\vinscent\.tmp\candidate-cloudflare-smoke.json'

npm.cmd run eval:candidates *> D:\vinscent\.tmp\candidate-cloudflare-smoke.log
$LASTEXITCODE
```

## Groq smoke 실행

Groq 무료 한도는 조직 단위로 적용된다. 기본 호출 간격은 15초이며, 현재 공식 무료 한도인
30 RPM과 8K TPM을 동시에 넘기지 않도록 보수적으로 잡은 값이다. 실제 계정 한도는 Groq
Console의 Limits 화면을 우선한다.

```powershell
cd D:\vinscent\services\ai-api

$env:GROQ_API_KEY = '<groq-api-key>'
$env:AI_CANDIDATE_EVAL_PROVIDERS = 'groq'
$env:AI_CANDIDATE_EVAL_SUITE = 'smoke'
$env:AI_MODEL_EVAL_RUNS = '1'
$env:AI_CANDIDATE_EVAL_OUTPUT = 'D:\vinscent\.tmp\candidate-groq-smoke.json'

npm.cmd run eval:candidates *> D:\vinscent\.tmp\candidate-groq-smoke.log
$LASTEXITCODE
```

비밀키는 현재 PowerShell 세션의 환경변수로만 전달하며 로그나 JSON 보고서에 기록하지
않는다.

## OpenAI smoke 실행

API 키 값은 문서나 저장소에 기록하지 않고 현재 PowerShell 세션에만 설정한다.

```powershell
cd D:\vinscent\services\ai-api

$env:OPENAI_API_KEY = '<openai-api-key>'
$env:AI_CANDIDATE_EVAL_PROVIDERS = 'openai'
$env:AI_CANDIDATE_EVAL_SUITE = 'smoke'
$env:OPENAI_EVAL_MODELS = 'gpt-5-nano'
$env:OPENAI_EVAL_REASONING_EFFORT = 'minimal'
$env:AI_MODEL_EVAL_RUNS = '1'
$env:AI_CANDIDATE_EVAL_OUTPUT = 'D:\vinscent\.tmp\candidate-openai-smoke.json'

npm.cmd run eval:candidates *> D:\vinscent\.tmp\candidate-openai-smoke.log
$LASTEXITCODE
```

## 전체 47개 평가

smoke를 통과한 모델만 쉼표로 지정한다. 아래 예시는 공급자별 모델 하나를 비교한다.

```powershell
$env:AI_CANDIDATE_EVAL_PROVIDERS = 'cloudflare,groq'
$env:AI_CANDIDATE_EVAL_SUITE = 'full'
$env:CLOUDFLARE_WORKERS_AI_EVAL_MODELS = '@cf/zai-org/glm-4.7-flash'
$env:GROQ_EVAL_MODELS = 'openai/gpt-oss-120b'
$env:GROQ_EVAL_REASONING_EFFORT = 'low'
$env:GROQ_EVAL_CASE_DELAY_MS = '15000'
$env:AI_MODEL_EVAL_RUNS = '1'
$env:AI_CANDIDATE_EVAL_OUTPUT = 'D:\vinscent\.tmp\candidate-model-full.json'

npm.cmd run eval:candidates *> D:\vinscent\.tmp\candidate-model-full.log
$LASTEXITCODE
```

최종 후보만 `AI_MODEL_EVAL_RUNS=3`으로 반복한다. 무료 할당량과 일일 한도를 확인한 뒤
공급자별로 나눠 실행해도 보고서의 평가 조건은 동일하다.

```powershell
$env:AI_CANDIDATE_EVAL_PROVIDERS = 'groq'
$env:AI_CANDIDATE_EVAL_SUITE = 'full'
$env:GROQ_EVAL_MODELS = 'openai/gpt-oss-120b'
$env:GROQ_EVAL_REASONING_EFFORT = 'low'
$env:GROQ_EVAL_CASE_DELAY_MS = '15000'
$env:AI_MODEL_EVAL_RUNS = '3'
$env:AI_CANDIDATE_EVAL_OUTPUT = 'D:\vinscent\.tmp\candidate-groq-120b-stability-3x.json'

npm.cmd run eval:candidates *> D:\vinscent\.tmp\candidate-groq-120b-stability-3x.log
$LASTEXITCODE
```

OpenAI 최저가 후보의 전체 47개 평가는 다음처럼 실행한다.

```powershell
$env:AI_CANDIDATE_EVAL_PROVIDERS = 'openai'
$env:AI_CANDIDATE_EVAL_SUITE = 'full'
$env:OPENAI_EVAL_MODELS = 'gpt-5-nano'
$env:OPENAI_EVAL_REASONING_EFFORT = 'minimal'
$env:OPENAI_EVAL_CASE_DELAY_MS = '0'
$env:AI_MODEL_EVAL_RUNS = '1'
$env:AI_CANDIDATE_EVAL_OUTPUT = 'D:\vinscent\.tmp\candidate-openai-gpt5-nano-full.json'

npm.cmd run eval:candidates *> D:\vinscent\.tmp\candidate-openai-gpt5-nano-full.log
$LASTEXITCODE
```

## 판정 기준

- 총점보다 `production_regression` 실패를 먼저 본다.
- 8개 작업 중 schema 또는 생성 오류가 반복되는 모델은 제외한다.
- 한글 외 문자 혼입, 내부 참여자명 노출, 존댓말, 근거 없는 단정은 치명 회귀로 본다.
- `몰라`와 `없어` 처리, 상충 근거, 후속 질문 범위 보존, 카드 및 날씨 조건을 작업별로
  확인한다.
- 통과 후보끼리는 입력 및 출력 토큰, 총 지연 시간, 무료 한도 지속 가능성을 비교한다.
- 3회 반복에서 결과가 크게 흔들리는 모델은 단일 최고 점수와 무관하게 제외한다.

## 환경변수

| 이름 | 기본값 | 역할 |
|---|---|---|
| `AI_CANDIDATE_EVAL_PROVIDERS` | `cloudflare,groq` | 실행 공급자, `openai` 명시 가능 |
| `AI_CANDIDATE_EVAL_SUITE` | `smoke` | `smoke` 또는 `full` |
| `AI_MODEL_EVAL_RUNS` | `1` | 반복 횟수, 최대 3 |
| `AI_CANDIDATE_EVAL_OUTPUT` | 없음 | JSON 보고서 경로 |
| `CLOUDFLARE_WORKERS_AI_EVAL_MODELS` | 후보 4개 | Cloudflare 모델 목록 |
| `CLOUDFLARE_EVAL_CASE_DELAY_MS` | `0` | Cloudflare 사례 간격 |
| `GROQ_EVAL_MODELS` | GPT-OSS 120B, 20B | Groq 모델 목록 |
| `GROQ_EVAL_REASONING_EFFORT` | `low` | `low`, `medium`, `high` |
| `GROQ_EVAL_CASE_DELAY_MS` | `15000` | Groq 사례 간격 |
| `OPENAI_API_KEY` | 없음 | OpenAI 선택 시 필요한 API 키 |
| `OPENAI_RESPONSES_ENDPOINT` | 공식 Responses API | 선택적 엔드포인트 재정의 |
| `OPENAI_EVAL_MODELS` | GPT-5 nano | OpenAI 모델 목록 |
| `OPENAI_EVAL_REASONING_EFFORT` | 모델별 자동 선택 | `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max` |
| `OPENAI_EVAL_CASE_DELAY_MS` | `0` | OpenAI 사례 간격 |

## 공식 근거

- Groq Structured Outputs: https://console.groq.com/docs/structured-outputs
- Groq Reasoning: https://console.groq.com/docs/reasoning
- Groq Rate Limits: https://console.groq.com/docs/rate-limits
- Cloudflare Workers AI Models: https://developers.cloudflare.com/workers-ai/models/
- Cloudflare Workers AI Pricing: https://developers.cloudflare.com/workers-ai/platform/pricing/
- OpenAI Structured Outputs: https://developers.openai.com/api/docs/guides/structured-outputs
- OpenAI GPT-5 nano: https://developers.openai.com/api/docs/models/gpt-5-nano
- OpenAI GPT-5.4 nano: https://developers.openai.com/api/docs/models/gpt-5.4-nano
- OpenAI GPT-5.6 Luna: https://developers.openai.com/api/docs/models/gpt-5.6-luna
- OpenAI Under 18 API Guidance: https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance
