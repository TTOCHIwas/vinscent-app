# 문맥 분류 후보 구현과 호출 전 계획

작성일: 2026-10-29. 구현 `5f9b50d6`, 브랜치 `codex/content-safety-foundation`.
현재 상태는 평가 도구 연결·테스트 완료, 실제 후보 API 호출 0건이다.
실제 분류 품질·지연·청구액·계정의 모델 접근 권한은 아직 측정하지 않았다.
사람 청취는 사용자 지정에 따라 0/8 미완료로 유지했다. 기존 결과와 로컬 변경은 보존했다.

## 범위와 비교 후보

기존 [문맥 검토](../content-safety-context-policy-review-2026-10-29/README.md)의
강요 차단·위해 금지 허용 기준을 일반 문맥 지시문으로 작성했다.
이를 읽고 구조화된 결과를 내는 OpenAI Responses 후보 두 개를 구현했다.

| 후보 | 역할과 공식 사양 | 이번 설정 |
| --- | --- | --- |
| [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna) | 비용을 낮춘 비교 후보. 구조화된 출력과 reasoning none 지원 | `gpt-6-luna`, none, default tier |
| [GPT-6.1 Terra](https://developers.openai.com/api/docs/models/gpt-6.1-terra) | 다른 모델 용량에서 같은 정책을 비교하는 후보. 구조화된 출력과 none 지원 | `gpt-6.1-terra`, none, default tier |

공식 사양 확인일은 2026-10-29다. 모델의 문서상 기능이 한국어 안전 분류 품질을 보증하지 않는다.
공개 문서에 제공된 모델 alias를 고정하고 실제 실행 시 응답 model도 기록한다. 자동 대체·fallback은 없다.
계정에서 해당 alias가 지원되지 않으면 실패로 중단한다. 이번 준비에서는 키를 읽거나 모델 권한을 조회하지 않았다.
기존 moderation 공급자·제품 `src`·저장 caller·DB/Storage·앱 배포는 변경하지 않았다.

## 입력과 정책 계약

[transmission-preview.json](transmission-preview.json)에 실제 전송할 지시문·출력 스키마·설정·12개 합성 문장을 보존했다.
`caseIdForLocalInventoryOnly`는 로컬 인계용 식별자이며 API에는 보내지 않는다.
API의 user 입력은 `{text: 실제 합성 문장}`뿐이다. 기대 라벨·사례 ID·그룹·해설·모범 답안을 보내지 않는다.
원본 [content-safety-context-ko.ts](../../../services/ai-api/eval/fixtures/content-safety-context-ko.ts)의 12개를 유지했다.
이 도구에서는 사진·OCR·음성·ASR을 재호출하지 않으며 실제 사용자 자료도 전송하지 않는다.

[context-policy.ts](../../../services/ai-api/eval/context/context-policy.ts)의 지시문과 계약은 다음과 같다.

- 정책 버전 `ko-context-candidate-v1`, 상태 draft. 일반적인 모든 유해 범주를 대신하는 정책이 아니다.
- 모델은 `coercion`, `direct_threat`, `harm_prevention`, `benign`, `unresolved_context` 중 문맥을 판정한다.
  응답의 intent와 allow/block/unavailable이 정책 계약과 모순되면 실패한다. 기대 라벨로 결과를 덮어쓰지 않는다.
- 금지 문구가 있어도 직접 위해·유포 협박이 남는 혼합 문맥을 구분하도록 지시한다.
  미정인 피해 진술·도움 요청·허구·인용과 판단이 어려운 문맥은 unavailable을 요청한다.
- 근거는 실제 입력의 연속 부분 1~3개만 허용하고 입력에 없는 문구·중복·빈 근거는 거부한다.
  부분 문자열 일치는 형식·정합성 확인이며 의미 판정이 정확하다는 증거는 아니다.
- `strict` JSON schema를 요청하고 서버 측에서도 정책 버전·자료형·허용 enum·추가 필드·근거를 재검증한다.
  refusal·잘린 응답·tool output·중복 메시지·응답 실패·잘못된 usage/model은 allow로 바뀌지 않는다.
- 결과에는 실제 판정·intent·근거 해시·model·토큰 수·지연·실패 코드만 남긴다.
  전사/입력 원문·자유 서술 추론·키·공급자 오류 본문은 결과에 기록하지 않는다.

기존 학습용 structured-generation client는 잘못된 출력에 재시도하는 계약이 있어 그대로 사용하지 않았다.
인증·본문 한도·오류 정제를 담당하는 기존 `requestContentSafetyJson`만 재사용하고 평가 어댑터에는 재시도를 넣지 않았다.
호출 흐름은 `CLI 승인 확인 → 공통 요청 budget → 후보 adapter → Responses → 계약 검증 → 원문 없는 집계`다.

## 승인받을 실제 호출 범위

| 선택 | 전송과 최대 호출 | 예상 USD | 보수적 추정 USD |
| --- | --- | --- | --- |
| [luna](luna-plan.json) | 합성 문장 12개 × Luna 1회 = 12회 | $0.006072 | $0.018072 |
| [terra](terra-plan.json) | 동일 12개 × Terra 1회 = 12회 | $0.060720 | $0.180720 |
| [both](both-plan.json) | 문장별 Luna → Terra 순서, 합계 최대 24회 | $0.066792 | $0.198792 |

[공식 가격](https://developers.openai.com/api/docs/pricing)은 백만 토큰당 Luna 입력 $0.10·출력 $0.50,
Terra 입력 $1·출력 $5다. 위 모델 문서의 cache write 단가(각 $0.125, $1.25)를 입력 비용에 적용해
캐시 저장 25% 추가 비용까지 여유로 반영했다. 캐시 적중 할인은 예상 비용에서 빼지 않았다.
기본 추정은 회당 입력 2,000·출력 최대 512토큰, 보수적 추정은 입력 10,000·출력 512토큰이다.
실제 토큰화나 청구액을 측정한 값이 아니며 세금·계정 계약을 제외하므로 금액의 확정 상한 보장이 아니다.
표준 tier, 도구 없음, 추가 OCR/ASR 없음이다. 고정된 현재 입력의 최대 직렬화 요청 크기는 2,346 bytes로 로컬 확인했다.

하드 제한은 요청 수 12/24, 재시도 0, 건당 20초, 입력 text 1,200 UTF-8 bytes,
요청 본문 8,192 bytes, 출력 512토큰이다. 관측 usage가 입력 10,000 또는 출력 512를 초과하면 중단한다.
첫 HTTP·전송·스키마·시간 초과 실패에서 모든 후보의 나머지 실행을 중단하고 부분 결과를 보고한다.
정상적인 모델 unavailable은 실제 판정으로 남긴다. usage 누락은 null로 기록하며 0으로 추정하지 않는다.

기본 선택 both의 승인 지문:
`fc1301ef9114cda9d935b704d3fb3979da9887e22425970985fbc4ed35849272`.
승인은 모델·전송 문장·정책 지시문·스키마·실제 공통 요청 설정·토큰/시간 한도·비용 가정에 묶인다.
선택이나 내용이 바뀌면 지문도 바뀐다. 이 문서의 계획은 아직 실행 승인을 받은 상태가 아니다.

## 외부 전송·보관

승인 시 위 합성 텍스트와 정책/스키마만 `https://api.openai.com/v1/responses`로 보낸다.
`store:false`, foreground, tools 없음으로 설정한다. 응답 조회용 application state 저장을 끄지만
일반 abuse monitoring의 기본 최대 30일 보관이나 prompt cache의 임시 보관까지 없앤다고 해석하지 않는다.
공식 안내상 prompt cache의 암호화된 KV 상태는 최대 24시간 보관될 수 있다.
계정의 별도 ZDR/MAM·지역 처리 설정은 조회하지 않았다.
[OpenAI 데이터 제어](https://developers.openai.com/api/docs/guides/your-data)의 Responses 조건을 따른다.
이전 moderation/전사 endpoint의 보관 조건을 이번 Responses 호출에 확대 적용하지 않는다.

## 실행과 결과 해석

```powershell
cd services/ai-api
npm.cmd test
npm.cmd run --silent eval:context
npm.cmd run --silent eval:context -- --candidate=luna
npm.cmd run --silent eval:context -- --candidate=terra
```

위 명령은 모두 키 없이 계획만 출력하고 외부 요청은 0건이다. Mac에서는 `npm`을 사용한다.
실제 승인 후에만 현재 지문과 `--live --approved-plan=<지문>`을 함께 지정한다.
유효한 `CONTENT_SAFETY_OPENAI_API_KEY`가 필요하며 env 파일은 도구가 자동으로 읽지 않는다.
키 파일·값은 인계하지 않고, 안전하게 해당 실행 프로세스에만 로드한다.

초안 라벨 10개만 정확도·오허용·오차단·판정 불가 분모에 넣고 미정 2개는 관측 판정을 별도로 남긴다.
미정 사례에서 모델이 allow를 내도 unavailable로 바꾸지 않는다. 해당 결과는 점수 통과 근거가 아니라 정책 검토 자료다.
기본 실험은 한 번의 고정 순서이며 순서 교차·반복 실행·독립 표본 검증을 대신하지 않는다.
CLI 종료 0은 정해진 초안 라벨의 자동 실험 통과만 뜻하고, 모든 출력에서 `ready=false`·게시 권한 없음이다.
기존 [실측의 강요/금지 오류](../content-safety-media-evaluation-2026-10-29/README.md)와 새 결과를 별도로 비교한다.
이번에는 단위 테스트의 모의 모델 결과를 라이브 실측으로 저장하지 않았다.

## 검증과 다음 인계

- baseline 443개 + 신규 28개 = Node 회귀 471개 통과. 실패/건너뜀 0.
- RED `6a6ed379`, 추가 경계 RED `0fa5c642`, GREEN 구현 `5f9b50d6`.
- 후보 adapter line/branch 100%/86.67%, 정책 codec 100%/92.68%, 비교 evaluator 100%/96.05%, plan 100%/100%.
  CLI 80%/55.56%는 계획·승인 거부 경로 테스트이며 유료 CLI end-to-end는 미실행이다.
  전체 로드 파일(테스트 포함)은 94.11%/87.22%다. 테스트 수치가 실제 분류 품질은 아니다.
- 실제 fetch body 설정 hash와 승인 계획 hash가 일치하는 테스트를 추가했고 독립 code/TypeScript 리뷰를 통과했다.
- 제품 저장·DB/Storage·배포·기존 공급자 정책과 기존 평가 보고서는 보존했다.

다음은 사용자가 선택한 계획의 모델·자료·호출 수·예상 금액을 확인한 후 실제 평가하는 단계다.
사람 청취와 확장 한국어 표본·라벨 검토는 여전히 남아 있다. 작은 초안 자료 통과만으로 공급자를 확정하지 않는다.
사용자가 작업 종료 후 컴퓨터 종료를 직접 승인했으므로, 이번 인계 저장·push 이후 Windows 정상 종료를 요청한다.
종료 승인은 이 문서의 새 유료 API 실행 승인으로 취급하지 않는다.
