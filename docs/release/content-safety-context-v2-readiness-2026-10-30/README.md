# 문맥 정책 v2 평가 연결과 호출 전 계획

작성일: 2026-10-30. 구현 `59979b48`, 실험 지문 검증 보강 `e42ceba2`, 브랜치 `codex/content-safety-foundation`.
이 문서는 호출 전 준비 기록이며 당시 실제 v2 API 호출과 키 파일 읽기는 0회였다.
이후 사용자가 both 계획을 승인했고 [실제 부분 결과](../content-safety-context-v2-evaluation-2026-10-30/README.md)에
정상 28회와 29번째 HTTP 500 중단을 기록했다. 재시도·추가 호출은 없었다.
이번의 모의 실행·테스트 결과를 실제 모델 관측으로 저장하지 않았다.

## 연결한 범위

[정책 제안과 공개 사례 근거](../content-safety-context-expansion-2026-10-30/README.md)의
`ko-context-proposal-v2`와 기존 추가 합성 문장 28개를 사용한다. 원본 표본·제안 라벨을 수정하지 않았다.
피해 진술·도움 요청과 명확한 허구 인용을 문맥상 허용하되 직접 위협·강요는 차단하고 불명확한 경우 보류한다.
실제 공급자가 이 정책을 따르는지는 새 평가 전까지 알 수 없다.

- `createContextExpansionExperiment`: 자료 형식·기존 자료 중복을 확인하고 정책/자료를 복사 후 재귀적으로 동결한다.
  생성한 실험 객체만 어댑터·계획·비교기에 주입하며 임의로 복제한 객체는 거부한다.
- `OpenAiContextExpansionCandidate`: 실제 입력 텍스트와 일반 정책만 Responses API로 전송한다.
  제안 정답·그룹·사례 ID·해설·기존 모델의 답변을 요청에 넣지 않는다.
- 응답 schema는 정책 버전·decision·intent·evidence 4개 필드를 요구한다.
  새 `victim_report`, `fictional_quote` intent를 허용하며 두 intent의 allow와 다른 intent/decision의 정합성을 검증한다.
  1~3개 근거가 실제 입력의 정확한 연속 부분인지도 확인한다. 이 검사는 의미 판단의 정확성을 증명하지 않는다.
- 기존 v1과 새 v2는 정상 완료·단일 assistant message·refusal/tool output 거부·모델/usage 검증을
  `context-response.ts`로 공유한다. 정책 parser와 schema는 분리했다.
- v1 지시문·기존 12개 라벨·승인 지문 `fc1301ef...`·실측·24회 제한은 보존했다.
  기존 미디어용 request budget의 최대 34회 제한도 바꾸지 않았다. v2 전용 budget만 28/56회를 허용한다.

호출 흐름은 `고정 합성 자료 → 동결한 실험 → 계획 지문 확인 → 키 존재 확인 → 공통 호출 수 제한 →
모델 어댑터 → 응답/정책 검증 → 초안 라벨과 미정 사례 분리 집계`다.
제품 src·저장 caller·운영 DB/Storage·모바일·배포는 변경하지 않았다.

## 실제 호출 전 확인할 계획

| 선택 | 고정 모델 | 최대 호출 | 예상 USD | 보수적 추정 USD |
| --- | --- | --- | --- | --- |
| [luna](luna-plan.json) | `gpt-6-luna` | 28 | $0.014168 | $0.042168 |
| [terra](terra-plan.json) | `gpt-6.1-terra` | 28 | $0.141680 | $0.421680 |
| [both](both-plan.json) | 문장별 Luna → Terra | 56 | $0.155848 | $0.463848 |

전송 자료는 기존 추가 합성 한국어 28문장, 일반 정책 지시문, 출력 schema·요청 설정이다.
[transmission-preview.json](transmission-preview.json)에 정확한 전송 내용을 보존했다.
`caseIdForLocalInventoryOnly`는 로컬 목록용이며 실제 API user 입력에는 `{text}`만 들어간다.
이미지·음성 원본·OCR/ASR·실제 사용자 자료·운영 DB 내용은 전송하지 않는다.

[Luna 공식 사양/가격](https://developers.openai.com/api/docs/models/gpt-6-luna)과
[Terra 공식 사양/가격](https://developers.openai.com/api/docs/models/gpt-6.1-terra)을 2026-10-30 확인했다.
백만 토큰당 입력/출력은 각각 $0.10/$0.50, $1/$5다. 입력에는 cache write 여유 단가 $0.125/$1.25를 적용했다.
기본 추정은 회당 입력 2,000·출력 512토큰, 보수적 추정은 입력 10,000·출력 512토큰이다.
실제 usage·청구액·캐시 적중·계정 잔여량을 확인한 값이 아니며 세금·계약 조건을 제외한다.
따라서 금액의 확정 상한은 아니다. 모델 alias 접근 권한과 현재 키 유효성도 이번에 조회하지 않았다.

고정 설정은 Responses API, reasoning `none`, default tier, `store:false`, stream false, tools 없음이다.
최대 출력 512토큰, 입력 text 1,200 UTF-8 bytes, 요청 body 8,192 bytes, 건당 20초, 재시도 0회다.
현재 28개에 대한 최대 실제 직렬화 요청은 Luna 3,095·Terra 3,098 bytes다.
관측 input/output usage가 10,000/512를 넘거나 형식이 잘못되면 unavailable로 중단한다.
usage 누락은 null이며 측정된 0으로 바꾸지 않는다. 모델을 자동 대체하지 않는다.

기본 both 계획 지문:
`e1d605fa44cca0845fb5fc9aa749736a903ea816d4c99986847c007d37d65ef4`.
자료·정책 지시문·schema·실제 요청 설정·모델·호출 수/토큰/시간 제한·비용 가정을 묶는다.
선택이나 내용이 달라지면 지문도 달라진다. 기존 24회 승인과 이 작업의 구현 승인은 새 56회 호출 승인이 아니다.

## 실패와 해석 경계

초안 라벨 24개(allow 15/block 9)만 제안 일치·오허용·오차단·판정 불가 분모에 넣는다.
정답 미정 4개는 expected null이며 모델 관측 allow/block/unavailable을 그대로 별도 보존한다.
미정 모델 allow를 기대 unavailable로 바꾸어 성공으로 세지 않으며 `unresolvedModelAllows`에 표시한다.
`allScoredProposalsMatched`와 CLI exit 0은 제안 라벨 일치만 뜻한다. 실제 운영 허용 권한이 아니다.

첫 HTTP·전송·시간 초과·JSON/schema·정책/모델/usage 검증 실패에서 모든 후보의 남은 실행을 중단한다.
실패 행은 unavailable이고 원문·키·공급자 오류 본문 대신 고정 오류 코드만 보고한다.
정상적인 모델 unavailable은 관측 결과로 남긴다. 기대 라벨이나 고정 성공값으로 모델 응답을 대체하지 않는다.

새 표본과 정책은 같은 에이전트가 만들었으며 사람 라벨 검토는 0/28이다.
`humanLabelReviewsCompleted=0`, `independentlyValidated=false`, `ready=false`,
`productionPublicationAuthorized=false`, `humanListeningPerformed=false`, `originalAudioCovered=false`를 유지한다.
미정 문맥의 사람 라벨, 독립 표본·반복/순서 교차 검증과 원본 미디어 검증은 여전히 남아 있다.

## 외부 전송·보관과 실행

승인 후 합성 텍스트와 일반 정책/schema만 `https://api.openai.com/v1/responses`에 보낸다.
`store:false`는 응답 조회용 상태 저장을 끄는 설정이다. 일반 abuse monitoring 최대 30일이나
암호화된 prompt-cache KV의 최대 24시간 임시 보관까지 없애는 설정으로 해석하지 않는다.
계정의 ZDR/MAM·지역 처리 설정은 조회하지 않았다.
[OpenAI 데이터 제어](https://developers.openai.com/api/docs/guides/your-data)를 따른다.

```powershell
cd services/ai-api
npm.cmd test
npm.cmd run --silent eval:context-expansion-live
npm.cmd run --silent eval:context-expansion-live -- --candidate=luna
npm.cmd run --silent eval:context-expansion-live -- --candidate=terra
```

명령 이름에 live가 있어도 위 기본 명령은 키를 읽지 않고 네트워크 0건의 계획만 출력한다.
Mac에서는 `npm`을 사용한다. 실제 승인 후에만 `--live --approved-plan=<선택한 최신 지문>`을 추가한다.
키 파일은 자동 로드하지 않으며 기존 `CONTENT_SAFETY_OPENAI_API_KEY`를 해당 평가 프로세스에만 설정한다.
지문을 먼저 확인하므로 이전 계획·누락된 승인은 키 접근 전에 거부한다. 키 파일은 Git에 포함하지 않는다.

## 검증과 인계

- 최초 RED `958fac6e`: 새 어댑터/실험/실행 모듈 없음. 추가 검증 테스트 `9272f5bb`.
  GREEN `59979b48`. 테스트·구현·문서 커밋을 분리했다.
- 기존 497 + 신규 28 = 전체 Node 회귀 525개 통과, 실패·건너뜀 0.
- 별도 프로세스에서 fetch를 모의 응답으로 교체해 CLI 전체 56회와 첫 HTTP/schema 실패 1회 중단을 검증했다.
  모의 테스트의 제안 답안 조회는 테스트에만 있다. 실제 어댑터와 실행기는 라벨을 API 응답으로 대체하지 않는다.
- 관련 coverage: 새 adapter line/branch 100%/88.89%, experiment 100%/93.55%, plan 100%/100%,
  evaluator 100%/98.46%, 공통 응답 parser 100%/95.83%, CLI 100%/85.71%.
  기존 v1 테스트도 통과했다. 테스트 수치는 실제 한국어 품질·지연·가격 측정이 아니다.
- 세 선택의 저장 계획과 재생성 결과, 지문, 28개 전송 미리보기, 최대 body 크기, v1 계획 지문 일치를
  오프라인으로 검증했다. 키 패턴·문서 상대 링크·공백 오류 검사도 통과했다.
- 키 파일·모델·가상 환경은 포함하지 않는다. 기존 로컬 변경과 과거 보고서는 보존한다.

작성 당시 다음 단계는 사용자가 선택한 모델·28개 합성 문장·최대 호출 수·예상 비용을 확인한 후 실제 평가하는 것이었다.
2026-10-30 위 both 계획을 1회 승인받아 실행했으나 HTTP 500으로 미완료 중단했다.
이전 계획을 다시 실행하거나 남은 요청을 자동 재개하지 않는다. 후속 범위는 새 실측 보고서를 따른다.
결과는 새 실측 보고서에 기록하며 이전 v1의 10/10과 분모가 다른 값으로 취급한다.
실제 OCR/ASR 관측문 조합과 원본 이미지·음성 품질 검증은 이번 연결 범위가 아니다.
운영 공급자 선정·제품 저장/공개 흐름·운영 DB/Storage·앱 배포도 진행하지 않았다.
