# 실제 미디어 추출과 문맥 후보 연결

작성일: 2026-10-30. 연결 구현 `c75ce61a`, 부분 인식 보완 `52589ade`, 출처 검증 보강 `5a46e13a`.
브랜치 `codex/content-safety-foundation`. 이번 외부 API 호출·키 파일 읽기는 0회다.
기존 합성 미디어 24개를 실제 로컬 OCR/VAD/ASR로 처리하고, 완료된 관측으로만 문맥 요청 본문을 준비했다.
문맥 후보·일반 시각 검사의 새 실제 API 평가는 아직 하지 않았다.

## 연결한 흐름과 검사 범위

`SHA-256 확인한 실제 bytes → 로컬 디코딩/OCR 또는 VAD/ASR → 검증된 추출 결과 →
같은 관측문을 Luna/Terra에 전달 → 문맥·시각 관측을 분리 기록`하는 평가 전용 경로다.
기존 `MediaExtractionAdapter`, `NativeMediaRuntime`, `OpenAiTranscriptionAdapter`,
`OpenAiContextExpansionCandidate`와 시각 moderation 어댑터를 조합한다.
기대 대본은 추출 결과가 나온 뒤 CER 비교에만 쓰고 OCR/ASR나 분류 요청에 넣지 않는다.

- 한 미디어의 추출은 후보 간 공유한다. 이미지 자체 판정도 한 번만 호출해 공유한다.
  후보별 차이와 ASR/OCR 재호출 차이를 섞지 않는다.
- 이미지 시각 검사가 block이면 문맥 allow로 덮어쓰지 않는다. 시각·문맥 모두 정상이어야 해당 범위의 allow가 나온다.
- 문맥 모델의 unavailable은 의미 판단 보류로 기록한다. 잘못된 응답·모델·usage·근거·시간 초과는 실행 오류다.
  첫 실행 오류에서 전체를 중단하며 정상 보류와 구분한다.
- 이미지의 OCR `no_text`는 빈 글의 증명이 아니다. 새 조합에서는 시각 allow여도 unavailable이다.
  기존 `evaluateMediaSafety`의 no-text 동작은 보존하고 새 경로에만 이 제한을 적용했다.
- `partial`/실패/미지원/무음은 문맥 요청을 만들지 않는다. 외부 평가 대상이 아닌 합성 대조군은
  VAD/OCR에서 뜻밖의 글이 나와도 외부로 보내거나 허용하지 않는다.
- 일반 유해 텍스트 전체 범주를 검사하는 조합이 아니다. `generalTextSafetyCovered=false`다.
  문맥 정책은 피해 진술·허구·위협·강요 등의 평가용 초안이고 일반 텍스트 moderation의 대체물로 확정하지 않았다.
- 음성은 전사된 말의 문맥 검사만 다룬다. 원음의 비명·억양·배경음·성적 소리 등을 검사했다고 해석하지 않는다.
  `originalAudioCovered=false`, 사람 청취 미완료·게시 권한 없음 flag를 유지한다.

부분 상태를 놓치던 지점도 보완했다. 추출 어댑터는 명시적인 OCR/ASR status가 complete가 아니면 완료로 올리지 않는다.
OpenAI 전사 어댑터도 명시적인 API status가 completed가 아니면 거부한다. status가 없는 기존 정상 응답은 유지했다.
따라서 앞단에서 partial을 표시한 응답이 중간 어댑터에서 상태를 잃고 정상으로 바뀌지 않는다.
디코더·모델이 오류 표시 없이 단어를 빠뜨린 경우까지 자동 판별하는 기능은 아니다.

## 실제 로컬 검증 결과

[local-extraction.json](local-extraction.json): 2026-10-30 19:01:31 KST (`2026-10-30T10:01:31.942Z`).
로컬 실행 기준은 `c75ce61a`이며 이후 출처 입력 검증을 보강했다. 같은 자료·요청 계획은 보존했다.
기존 격리 Python 환경, Windows 한국어 OCR, Silero v6.2와 Vosk small-ko-0.22를 사용했다.
대본·grammar·prompt·keyword를 인식 입력으로 사용하지 않았다.

| 구분 | 실제 관측 | 문맥 요청 준비 |
| --- | --- | --- |
| 한국어 이미지 8개 | complete 8개, CER 0은 7개·작은 글 1개 CER 0.1 | 후보별 8개 |
| 그림/기하 장면 2개 | no_text 2개 | 0개, 빈 글이 증명됐다고 보지 않음 |
| 발화 8개 | 계약상 complete 1개·partial 7개 | 후보별 1개 |
| 무음·잡음 2개 | no_speech 2개 | 0개 |
| 손상·미지원 4개 | failed 4개 | 0개 |

완료된 발화는 `audio-coercion-ko`이며 **CER 0.1875**다. 계약상 complete라도 대본과 정확히 일치한 것이 아니다.
완료 상태나 confidence가 전사 의미의 보존을 증명하지 못함을 보여준다. 이 문장을 기대 대본으로 고치지 않았다.
partial 7개는 어댑터가 텍스트를 반환하지 않아 이번 경로에서는 CER null이다. null을 0으로 채우지 않았다.
발화 8개가 정확했다고 보고하거나 기존 OpenAI ASR 8/8 CER 0 결과로 이번 로컬 품질을 대체하지 않는다.

실제 관측 9개에 대해 후보별 2개, 총 18개 HTTP 요청 본문의 해시를 만들었다. 외부 전송은 0건이다.
원문 대신 관측 텍스트 해시·완성된 요청 본문 해시만 저장했다. 요청 해시 생성이 분류나 HTTP 성공을 뜻하지 않는다.
`automaticTextQualityPassed=false`, CLI 종료 코드는 1이다. 테스트 실패가 아니라 현재 인식/검사 준비 품질의 미통과다.
`contextQualityEvaluated=false`이며 모의 분류 결과를 실제 결과로 기록하지 않았다.

기본 사례 24개를 실제 추출했고 원본 변형·추가 손상 코덱까지 전체 37개 파일 SHA-256을 확인했다.
별도로 실제 PyAV/Pillow 코덱 Python 테스트 8개도 통과했다. 이 수치들을 37개 모두의 새 OCR/ASR 품질 검증으로 합치지 않는다.
JPEG·WebP·M4A bytes는 네이티브 디코더로 처리했다. 사람이 음성을 들었다는 기록은 여전히 0/8이다.

## 새 유료 평가 전에 확인할 계획

새 실제 평가에서는 로컬 OCR/VAD를 쓰고 발화 인식만 `gpt-transcribe`로 처리한다.
그 결과를 실제 관측문으로 후보 간 공유한다. 기존 18개 텍스트나 v2/28문장 결과를 재사용하지 않는다.

| 선택 | 최대 API 구성 | 최대 호출 | 예상 USD | 보수적 추정 USD |
| --- | --- | --- | --- | --- |
| [luna](luna-plan.json) | 시각 10 + ASR 8 + 문맥 18 | 36 | $0.018108 | $0.036108 |
| [terra](terra-plan.json) | 시각 10 + ASR 8 + 문맥 18 | 36 | $0.100080 | $0.280080 |
| [both](both-plan.json) | 공유 시각 10 + 공유 ASR 8 + 문맥 후보별 18 | 54 | $0.109188 | $0.307188 |

문맥은 정상 이미지 10개 모두에서 글이 나올 수 있는 경우와 발화 8개를 합쳐 후보별 최대 18회로 제한했다.
OCR no_text 2개가 유지되고 발화 8개가 모두 정상 전사되면 문맥은 후보별 16회, 전체 호출은 50회가 된다.
이는 예상 경로일 뿐 실제 미디어 조합 실측은 아니다. 모의 CLI에서 50회 경로를 검증했고 최대 한도는 54회다.
각 단계 한도를 다른 단계로 빌려 쓰지 못하며 401/403/429/5xx·전송·응답 형식 실패에서 중단한다.

[Luna](https://developers.openai.com/api/docs/models/gpt-6-luna),
[Terra](https://developers.openai.com/api/docs/models/gpt-6.1-terra),
[GPT-Transcribe](https://developers.openai.com/api/docs/models/gpt-transcribe) 공식 가격을 2026-10-30 확인했다.
문맥 입력/출력은 백만 토큰당 Luna $0.10/$0.50, Terra $1/$5이며 입력에는 cache write 여유 단가 $0.125/$1.25를 적용했다.
기본 추정은 회당 입력 2,000·출력 512토큰, 보수적 추정은 입력 10,000·출력 512토큰이다.
ASR은 8개 × 파일당 최대 15초 = 2분, $0.0045/분 기준 $0.009를 포함했다.
[시각 moderation](https://developers.openai.com/api/docs/guides/moderation)은 무료다.
세금·계정 계약·캐시 적중·잔여량·실제 청구액은 미확인이고 금액은 확정 상한이 아니다.

both 새 승인 지문은 `16cba13f2c9b3e5e483b248ba1dc3f89d61d0f030cfad0b1a38e2367524504ca`다.
원본 manifest·24개 파일 해시/대상·문맥 지시문/schema/요청 설정·모델·단계별 수량/제한·비용을 묶는다.
기존 34/24/56/28회 승인을 이 평가에 재사용하지 않는다. 이번에는 계획과 로컬 검증만 진행했다.

## 실제 전송 자료와 보관

[transmission-scope.json](transmission-scope.json)에 파일 해시·전송 범위·정책/schema를 저장했다.

- 시각: 고정 합성 이미지 최대 10개, 실제 원본 PNG/JPEG/WebP bytes를 image data URL로 보낸다.
- ASR: 고정 합성 M4A 발화 8개를 로컬 PCM16 mono 16kHz WAV로 변환해 보낸다. 무음·잡음·손상/미지원 대조군은 전사 API에 보내지 않는다.
- 문맥: 실제 OCR 또는 새 ASR의 complete 한국어 텍스트만 보낸다. 정확한 관측문은 새 인식 결과에 따라 달라지며 기대 대본으로 고정하지 않는다.
- 실제 사용자 자료·운영 DB·키·정답 라벨·CER·기존 분류 답변은 입력에 넣지 않는다.

Responses 요청은 reasoning none·default tier·store false·stream false·tools 없음이다.
text 최대 1,200 UTF-8 bytes·요청 body 8,192 bytes·출력 512토큰 제한은 기존 v2 어댑터를 사용한다.
네이티브 작업은 내부 20초, 공통 추출은 30초, 후보별 시각/문맥 조합은 20초 제한이다.
외부 호출은 실제 관측 payload만 저장하지 않고 해시·판정·usage·지연·상태를 보고한다.

[OpenAI 데이터 제어](https://developers.openai.com/api/docs/guides/your-data)를 따른다.
Responses의 일반 abuse monitoring 최대 30일·prompt cache의 임시 보관은 store false로 없어지지 않는다.
전사와 moderation의 기본 보관 조건은 Responses와 구분하고 이미지 안전 예외·계정별 ZDR/MAM/지역 설정은 별도다.
계정 설정과 현재 키 유효성을 이번에 조회하지 않았다. 모델/endpoint를 자동 대체하지 않는다.

## 실행과 테스트

```powershell
cd services/ai-api
npm.cmd test
npm.cmd run --silent eval:media-context
npm.cmd run --silent eval:media-context -- --candidate=luna
npm.cmd run --silent eval:media-context -- --verify-local
```

기본은 키·네트워크 없이 계획만 출력한다. --verify-local에는 기존 CONTENT_SAFETY_PYTHON,
CONTENT_SAFETY_VAD_MODEL, CONTENT_SAFETY_ASR_MODEL 경로만 필요하며 키를 읽거나 API를 호출하지 않는다.
실제 유료 실행은 별도 확인 후 `--live --approved-plan=<선택한 새 지문>`을 쓴다.
그때만 CONTENT_SAFETY_OPENAI_API_KEY를 해당 프로세스에 설정한다. env 파일은 자동으로 읽지 않는다.
Mac에서는 npm을 사용하지만 이 네이티브 OCR 경로에는 Windows 한국어 OCR이 필요하다.

- RED `668aaa91`: 새 경로 없음과 부분 상태 누락. 추가 RED/검증 `cd153329`, 요청 준비 RED `f9a9ec26`.
- GREEN `52589ade`, `c75ce61a`. 출처/유형/외부 대상 검증 RED `e720566f`, GREEN `5a46e13a`.
- Node 기존 543 + 신규 23 = 전체 566개 통과, 실패·건너뜀 0. Python 실제 코덱 8개 통과.
- 모의 CLI는 실제 대신 관측 모의값을 사용했다고 명시하고 50회 경로·no_text 보류·ASR 8회 공유를 검증했다.
  네트워크 없는 로컬 모드의 요청 해시 준비와 모든 단계 예산 합계 최대 54회도 테스트했다.
- 관련 coverage: 조합 line/branch 100%/90.91%, 계획/예산 98.86%/84.62%, 추출 100%/95.31%,
  전사 100%/91.67%, CLI 100%/88.24%. 모의 테스트 결과를 실제 공급자 품질로 보고하지 않는다.
- 세 선택의 저장 계획과 재생성 지문·실제 로컬 24개/요청 해시 18개·37개 파일·문서 링크·키 패턴 검증을 통과했다.
- 제품 src·앱 저장 흐름·운영 DB/Storage·배포·기존 실측 파일·합성 bytes는 변경하지 않았다.

현재 no_text 그림 2개는 최종 unavailable이 되는 것이 새 실험의 의도된 보수적 경계다.
이미지의 글자 부재를 독립적으로 확인하는 방법이나 제품 그림 공유 정책이 확정됐다는 뜻이 아니다.
로컬 발화 complete 1개도 CER 0.1875이므로 단순 상태/신뢰도만으로 의미 보존을 보장할 수 없다.
다음 실제 API 평가에서도 CER와 분류 결과를 분리해 보고하고 원음·사진 전체 안전성으로 확대하지 않는다.
