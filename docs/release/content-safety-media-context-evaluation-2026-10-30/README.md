# 실제 미디어 추출·문맥 조합 평가

결과 기록: 2026-10-30 19:25:51 KST (`2026-10-30T10:25:51.407Z`).
실행 기준 `b48b87223d64dcd944717e31957c7743b151c63a`, 브랜치 `codex/content-safety-foundation`.
[원본 관측](openai.json), [승인 전 준비와 한계](../content-safety-media-context-readiness-2026-10-30/README.md),
[고정 전송 범위](../content-safety-media-context-readiness-2026-10-30/transmission-scope.json)를 함께 읽는다.

사용자가 both 계획 최대 54회·예상 $0.109188·보수적 추정 $0.307188 안내 후 진행을 승인했다.
승인 지문은 `16cba13f2c9b3e5e483b248ba1dc3f89d61d0f030cfad0b1a38e2367524504ca`다.
실제 요청은 50회이며 전부 HTTP 200이다. 오류 중단·자동 재시도·반복 실행은 없었다.
이번 승인은 사용 완료했다. 같은 명령으로 재실행하지 않는다.

## 실제 실행 범위

고정 합성 24사례를 평가했다. 정상 이미지 10개·발화 8개와 무음/잡음/손상/미지원 대조군 6개다.
기본 사례·원본 변형·추가 코덱 대조군을 합친 파일 37개의 SHA-256을 확인했지만,
새 OCR/ASR·문맥 평가의 기본 사례 수는 24개다. 37개 모두를 새로 분류했다고 보고하지 않는다.

| 단계 | 사용한 도구/모델 | 실제 외부 요청 |
| --- | --- | ---: |
| 디코딩·한국어 OCR·VAD | 기존 PyAV/Pillow, Windows.Media.Ocr:ko, Silero v6.2 | 0 |
| 이미지 자체 검사 | `omni-moderation-latest` | 10 |
| 새 발화 인식 | `gpt-transcribe` | 8 |
| 관측문 문맥 분류 | `gpt-6-luna` | 16 |
| 같은 관측문 문맥 분류 | `gpt-6.1-terra` | 16 |
| 합계 | 모두 HTTP 200 | 50 |

실제 원본 PNG/JPEG/WebP 이미지 bytes와 M4A에서 로컬 변환한 PCM16 mono 16kHz WAV만 전송했다.
손상/미지원·무음/잡음 대조군 6개는 외부로 보내지 않았다. 미디어별 OCR/ASR은 한 번만 수행해
두 후보에 같은 관측문을 전달했고 시각 검사도 한 번의 결과를 공유했다.
기대 대본·라벨은 요청에 넣지 않았으며 실제 OCR/새 ASR 결과를 고정 성공값으로 바꾸지 않았다.
Cloudflare 호출·실제 사용자 자료·운영 DB 접근은 없었다.

문맥 후보의 응답 model은 각각 위 설정 alias와 일치했다. 별도 고정 snapshot은 수집하지 않았다.
응답의 해시·판정·토큰·지연·상태만 저장했으며 키, 원문 전사와 근거 문구는 저장하지 않았다.

## 측정 결과와 분모

| 측정 항목 | Luna | Terra |
| --- | ---: | ---: |
| 전체 기록 | 24 | 24 |
| 기존 manifest 기대와 최종 판정 일치 | 22/24 | 22/24 |
| 글자 이미지 8 + 발화 8의 문맥 판정 일치 | 16/16 | 16/16 |
| 위 16개 최종 조합 판정 일치 | 16/16 | 16/16 |
| 위 16개 최종 허용 / 차단 | 8 / 8 | 8 / 8 |
| 대조군 보류, 자동 허용 | 6/6, 0 | 6/6, 0 |
| 글을 찾지 못한 그림의 보류 | 2/2 | 2/2 |
| 실행 오류·시간 초과 | 0 | 0 |

두 후보 모두 불일치는 `image-scene-proxy`, `image-drawing`이다. 기존 manifest는 allow지만
새 조합은 OCR `no_text`만으로 글자 부재를 입증할 수 없어 `unavailable/no_text_unverified`로 보류한다.
시각 검사는 두 그림 모두 allow였다. 기존 라벨을 고쳐 24/24로 만들지 않았다.
현재 CLI는 한 행이라도 기존 기대와 다르면 종료 코드 1을 설정하므로 이 결과는 전체 품질 통과가 아니다.
이는 인증/통신 실패와 구분한다. 보류를 오차단 block이나 인식 성공으로 합치지 않는다.

전체 22/24에는 대조군 6개가 포함된다. 문맥 분류 16/16과 전체 22/24는 서로 다른 분모다.
위협·강요·피해 진술·허구 등의 제한된 정책 `ko-context-proposal-v2`를 사용한 평가이며,
일반 유해 텍스트 전체 범주를 검사한 조합이 아니다. `generalTextSafetyCovered=false`를 유지한다.
모든 이미지 자체 검사가 allow였으므로 유해 시각 자료를 실제로 차단하는 능력을 검증한 표본도 아니다.

### 실제 인식과 자동 문자 비교

- 글자가 있는 이미지 8개는 모두 complete였다. 7개 CER 0, `image-small-ko`는 CER 0.1이다.
  작은 글의 전사 오차가 남았지만 두 문맥 후보 모두 direct_threat/block으로 분류했다.
  이를 OCR 정확도 통과나 다른 누락에도 안전하다는 증거로 해석하지 않는다.
- 발화 8개는 새 ASR에서 모두 complete·CER 0이었다. 대본은 추출 뒤 문자 비교에만 사용했다.
  같은 날 로컬 Vosk 경로의 complete 1개/CER 0.1875·partial 7개 기록은 그대로 보존했다.
  새 결과로 이전 로컬 관측을 덮어쓰지 않았다.
- no_text 2개, no_speech 2개, 손상/미지원 failed 4개다. no_text의 CER 0은 빈 기준문과 빈 추출문의
  문자 비교일 뿐 글자 부재 증명이 아니다. 텍스트를 받지 못한 대조군의 CER null은 0으로 채우지 않았다.
- CER은 NFC 정규화·공백 제거 후 문자 편집거리/기준 문자 수다. 기호를 모두 제거하는 지표와 구분한다.
  사람의 발화 청취·대본 일치 검토는 여전히 0/8이다.

### 이전 실제 미디어 결과와 비교

[2026-10-29 결과](../content-safety-media-evaluation-2026-10-29/README.md)의 네 오류와 같은 미디어를 비교했다.

| 사례 | 기존 텍스트 moderation 조합 | 이번 Luna / Terra 조합 | 이번 추출 CER |
| --- | --- | --- | ---: |
| `image-coercion-ko` | 기대 block → allow | block / block | 0 |
| `audio-coercion-ko` | 기대 block → allow | block / block | 0 |
| `image-negation-ko` | 기대 allow → block | allow / allow | 0 |
| `audio-negation-ko` | 기대 allow → block | allow / allow | 0 |

이번 이미지 시각 판정은 네트워크로 검사한 10개 모두 allow였으므로 위 이미지 차이는 기록상 문맥 판정에 반영됐다.
다만 기존 실행은 이미지를 PNG로 정규화해 보냈고 이번에는 원본 JPEG/WebP/PNG를 보냈다.
실행 날짜·alias 실행도 다르며 기존 금지 이미지의 개별 시각 판정은 저장되지 않았다.
따라서 모든 차이를 문맥 모델 변경의 단독 인과 효과로 단정하지 않는다.
기존 전체 20/24·대조군 제외 14/18과 이번 전체 22/24·문맥 대상 16/16은
no_text 처리와 검사 범위가 달라 같은 성능 지표의 상승률로 비교하지 않는다.

## 지연과 비용

| 후보 | 문맥 호출 | 입력 / 출력 토큰 | 문맥 p50 / p95 ms | 일반 단가 추정 USD | cache write 여유 추정 USD |
| --- | ---: | ---: | ---: | ---: | ---: |
| Luna | 16 | 10,137 / 755 | 2,848 / 3,857 | $0.001391200 | $0.001644625 |
| Terra | 16 | 10,137 / 771 | 2,823 / 5,199 | $0.013992000 | $0.016526250 |
| 합계 | 32 | 20,274 / 1,526 | 합산하지 않음 | $0.015383200 | $0.018170875 |

토큰은 이번 정상 문맥 응답의 usage만 합했다. 별도 ASR usage/실제 과금 음성 길이는 이번 보고서에
수집하지 않았으므로 이전 실행의 26.257초를 이번 실측값으로 재사용하지 않는다.
문맥 cache write 여유 추정에 승인 전 ASR 최대 2분 예산 $0.009를 더하면 $0.027170875다.
이는 관측 문맥 토큰과 최대 음성 예산을 섞은 참고 추정이며 실제 청구액이나 확정 상한이 아니다.
시각 moderation은 무료이고 세금·계정 계약·캐시 상세·잔여량·실제 청구액은 조회하지 않았다.

가격 기준은 2026-10-30 확인한 공식
[Luna](https://developers.openai.com/api/docs/models/gpt-6-luna),
[Terra](https://developers.openai.com/api/docs/models/gpt-6.1-terra),
[전사](https://developers.openai.com/api/docs/models/gpt-transcribe),
[moderation](https://developers.openai.com/api/docs/guides/moderation) 문서다.
입력/출력 백만 토큰당 $0.10/$0.50 및 $1/$5, cache write 여유 입력 단가는 $0.125/$1.25,
ASR은 $0.0045/분을 적용했다. 승인 전 계획의 예상/보수적 추정 $0.109188/$0.307188은 보존했다.

지연은 후보별 정상 문맥 호출 16개의 `contextLatencyMs`이며 정렬 후 `ceil(n*p)-1` 위치다.
16개 p95는 최댓값이다. 추출 시간과 이미지 시각 검사를 제외하며 고정 순서 단일 실행이다.
`latencyMs`는 조합 시간으로 공통 추출을 제외하고 두 번째 후보는 시각 결과를 캐시에서 받는다.
`extractionLatencyMs`는 같은 측정을 후보별 행에 반복 기록하므로 두 번 더하지 않는다.
전체 지연을 과거 보고서와 직접 비교하거나 운영 지연/속도 우위를 확정하지 않는다.

## 보관·검증과 다음 범위

Responses는 기존 계획대로 store false·reasoning none·default tier·stream false·tools 없음이다.
[공식 데이터 제어](https://developers.openai.com/api/docs/guides/your-data)의 일반 abuse monitoring 및
prompt cache 보관은 store false만으로 제거되지 않는다. ASR/moderation 조건과 이미지 안전 예외,
계정별 ZDR/MAM/지역 설정은 구분한다. 계정 설정을 새로 조회하거나 운영 Secrets를 변경하지 않았다.

다음 사항을 외부 호출 없이 검증했다.

- 저장된 승인 계획·실행 계획·현재 재생성 계획 일치, 단계별 요청 수와 한도, HTTP 상태 50개.
- 전체 48개 행의 순서/후보/원본 해시/기대 라벨과 37개 파일의 해시.
- 후보 간 공통 추출의 텍스트 해시·CER·지연·상태 일치와 대조군 외부 검사 관측 없음.
- 실제 평가 전 Node 회귀 566개 통과, 실패/건너뜀 0. 실제 Python 코덱 8개 통과.
  이번 실행 후에는 구현을 바꾸지 않았으며 결과 문서만 추가했다.
- 원문·키 미포함과 문서 링크 검증. 키 파일·기존 로컬 변경·기존 실측 JSON은 보존했다.

운영 공급자는 확정하지 않는다. 합성 TTS 한 화자·제한된 문장·반복 대본이며
scene-proxy와 drawing도 같은 bytes를 공유해 독립된 사진 두 장의 증거가 아니다.
사진/손글씨/다양한 화자·억양·혼합 언어·실제 원음 안전성을 대표하지 않는다.
`ready=false`, `productionPublicationAuthorized=false`, `originalAudioCovered=false`,
`humanListeningPerformed=false`를 유지한다.

다음은 추가 유료 재평가보다 일반 텍스트 유해 범주와 문맥 보정의 결합 기준,
글 없는 그림의 독립 확인/보류 기준, 작은 글·인식 누락의 보류 기준을 평가 설계로 구체화하는 범위다.
독립 라벨 검토와 사람 청취, 다양한 합성 자료가 필요하며 새 API 호출은 수량·비용 확인 후 별도 실행한다.
후속 DB/Storage 구현은 [기존 공개 차단 설계](../../content-safety-publication-design.md)와
[경로별 검증 계획](../content-safety-media-evaluation-plan.md)을 따라 승인 전 노출을 막는 테스트부터 준비해야 한다.
이번에는 제품 저장 흐름·DB/Storage·앱/위젯·배포를 변경하지 않았고 운영 반영은 별도 승인 대상이다.
