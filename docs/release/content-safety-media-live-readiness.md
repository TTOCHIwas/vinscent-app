# 실제 미디어 평가 도구와 호출 전 확인

확인일: 2026-10-27. 브랜치 `codex/content-safety-foundation`.
제품 저장 caller, 운영 DB/Storage, Edge Function과 앱 배포는 변경하지 않았다.
이번 실제 미디어 API 요청은 0건이다. 공개 모델·패키지 다운로드와 로컬 추론만 실행했다.
운영 공급자는 선정하지 않았다. 기존 [텍스트 18개 실측](content-safety-evaluation-2026-10-25/README.md)은 그대로 보존한다.

## 준비 상태와 실제 측정

합성 manifest는 24사례(이미지 12/음성 12), 기준 파일 24개, 원본 변형 10개,
추가 손상 코덱 대조군 3개다. 실제 사용자 자료·목소리 복제·외부 TTS는 사용하지 않았다.
Windows OneCore의 `Microsoft Heami` ko-KR로 대본 8개를 발화 WAV로 만들고 M4A/AAC도 저장했다.
이전 문서의 “한국어 음성 없음”은 SAPI만 확인한 결과였으며 OneCore에서는 가능했다.
같은 문장을 발화한 잡음 사례는 1.25배 속도·15 dB 잡음·seed 20261027로 구분했다.
WAV 합계 25.745초, M4A 디코딩 합계 26.257초다. AAC 인코더의 프레임 정렬 차이를 포함한다.

| 검증 | 관측 결과 | 해석 범위 |
| --- | --- | --- |
| 실제 디코딩/OCR/VAD/ASR 실행 | 27사례: 정상 디코딩 20, 예상 실패 7 | 파일이 읽히고 예상 오류가 차단되는 기술 검증 |
| Windows OCR | 이미지 10/10 정규화 일치 | 원본 우선, 빈 결과만 고정 보조 전처리. CER은 별도로 보존 |
| Silero VAD | 발화 8/8 감지, 무음/잡음 2/2 미감지 | 이 합성 표본에서의 관측. 감정·비명·안전성 판단 아님 |
| Vosk 한국어 ASR | 정규화 일치 1/8 | 대본 일치 품질 미통과. TTS 자체 오류와 ASR 오류를 분리하지 못함 |
| 사람 청취 | 0/8, 모두 미완료 | [청취 검토표](content-safety-speech-review.md). 자동 결과를 사람 확인으로 표시하지 않음 |
| 외부 미디어 안전 분류 | 미실행 | 지연·청구액·안전 판정 품질 미측정 |

[현재 자동 결과 JSON](content-safety-media-local-2026-10-27.json)의
`technicalVerificationPassed=true`, `automaticQualityPassed=false`를 구분한다.
품질 미통과 명령의 종료 코드는 1이며 숨기거나 성공으로 바꾸지 않는다.
[개선 전 결과](content-safety-media-local-2026-10-27-baseline.json)도 보존했다.
현재 결과는 원본 OCR을 우선하고 작은 저대비 글에서만 빈 결과 보조 처리를 추가한 뒤의 결과다.
개선 전에는 잡음 사례가 맑은 발화와 같은 신호였으며 현재는 명시된 잡음·속도 변형으로 교체했다.
이 표본으로 전처리를 조정했으므로 별도 미사용 표본을 추가해야 한다.

## 어댑터와 실패 경계

`run-media-evaluation.ts` → `MediaExtractionAdapter` → native decoder → 실제 OCR/VAD/ASR →
기존 공급자 분류 어댑터 순으로 연결했다. 제품의 `CheckSharedContent`·DB gateway에는 연결하지 않았다.
각 외부 I/O를 port로 주입하고 실패를 정제해 노출하는 기존 컨벤션을 따른다.

- Pillow: 실제 PNG/JPEG/WebP 픽셀 해석, MIME/포맷 일치, 단일 프레임, 최대 4096변·1600만 픽셀.
- PyAV: 실제 M4A/AAC·WAV·MP3 해석, 음성 스트림 1개·영상 없음, mono PCM16/16 kHz 정규화,
  15초·20 MiB 한도. 15초 AAC의 끝 패딩과 실제 15.2초 초과를 별도 테스트한다.
- OCR: Windows.Media.Ocr `ko`. 원본 우선, 실제 빈 결과에서만 고정 임계값/확대 보조 처리.
  글 누락을 완전히 검출하지 못하므로 OCR의 `no_text`만으로 이미지 안전을 보증하지 않는다.
- VAD: Silero v6.2 ONNX 실제 확률, 0.5 이상 연속 250 ms 근거를 요구한다. 에너지 임계값이나 고정 true를 사용하지 않는다.
- 로컬 ASR: Vosk small-ko-0.22, 실제 인식 단어의 최소 confidence 0.8 미만은 partial.
  ko는 단일 언어 모델 설정이며 언어 자동 감지 근거가 아니다. 높은 confidence도 정확성을 보증하지 않는다.
- OpenAI ASR: `gpt-transcribe`, 실제 파일을 multipart로 전송. `languages[]=ko` 외에 기대 대본·prompt·keywords를 보내지 않는다.
  실제 응답의 text/languages를 검사한다. 빈 결과·혼합/외국어·언어 불명·HTTP 오류는 실패한다.
  비어 있지 않은 한국어 응답도 전사 완전성을 증명하지 못하므로 CER·부정어·위협어 보존 검토가 필요하다.
- 신호 없음·부분 전사·NaN 감지값·손상 파일·미지원·취소·시간 초과는 allow로 바뀌지 않는다.
  이미지에는 시각 분류와 OCR 텍스트 분류를 함께 요구하고, 음성 허용 범위도 `transcribed_speech_only`다.
  `originalAudioCovered=false`이며 비언어적 위험까지 승인한 결과가 아니다.
- 네이티브 자식 프로세스에 API 키 환경변수를 넘기지 않는다. shell 없이 실행하고 종료·취소·출력 한도를 적용한다.
  보고서에는 원문 전사·키·계정 ID·응답 본문을 남기지 않는다.

## Windows 로컬 실행

Node >=22.6, Windows PowerShell 5의 `powershell.exe`, 한국어 OCR/Heami가 필요하다.
Mac에서는 순수 Node 테스트와 파일 무결성 검사만 실행할 수 있다. 현재 OCR/TTS 어댑터는 Windows 전용이다.
Python은 제품 의존성과 분리된 가상 환경을 사용한다. 이번 PC의 경로는 `D:/vinscent/.toolchains/content-safety-media`다.
다른 환경에서는 해당 위치를 직접 설정한다. 모델과 가상 환경·키 파일은 Git에 넣지 않는다.

```powershell
cd services/ai-api
$env:CONTENT_SAFETY_PYTHON = 'D:/vinscent/.toolchains/content-safety-media/Scripts/python.exe'
$env:CONTENT_SAFETY_VAD_MODEL = 'D:/vinscent/.toolchains/content-safety-media/silero-v6.2.onnx'
$env:CONTENT_SAFETY_ASR_MODEL = 'D:/vinscent/.toolchains/content-safety-media/vosk-model-small-ko-0.22'
npm.cmd test
& $env:CONTENT_SAFETY_PYTHON -m unittest discover -s eval/media -p test_media_runtime.py
npm.cmd run --silent eval:content-safety-media -- --validate-assets
npm.cmd run --silent eval:media-local
# 마지막 명령은 현재 ASR 품질 미통과로 보고서를 저장하고 종료 코드 1을 반환한다.
npm.cmd run --silent eval:media -- --provider=openai --asr=openai
npm.cmd run --silent eval:media -- --provider=cloudflare --asr=openai
```

의존성: `eval/media/requirements.txt`, Windows의 전체 고정 목록은 `requirements-windows.lock.txt`.
새 환경은 별도 venv에서 `python -m pip install -r eval/media/requirements-windows.lock.txt`로 설치한다.
모델은 다음 공식 파일에서 받는다. 설치에는 네트워크가 필요하지만 로컬 검증은 외부 API를 호출하지 않는다.

| 모델 | 출처 | 다운로드 SHA-256 |
| --- | --- | --- |
| Silero v6.2 (MIT) | [공식 ONNX](https://raw.githubusercontent.com/snakers4/silero-vad/v6.2/src/silero_vad/data/silero_vad.onnx) | `1a153a22f4509e292a94e67d6f9b85e8deb25b4988682b7e174c65279d8788e3` |
| Vosk ko 0.22 (Apache 2.0) | [공식 zip](https://alphacephei.com/vosk/models/vosk-model-small-ko-0.22.zip) | `eea36124087fed26c59996a4761519458e3bd185e8ea9d9865ad8760c4a1d989` |

Vosk는 zip 해시를 확인하고 풀어 모델 디렉터리를 지정한다. Silero는 실행 때도 ONNX 해시를 검사한다.
준비된 음성은 커밋된 bytes를 사용한다. `prepare-korean-media.ts --prepare`는 구버전 pending manifest의
최초 작성 도구이며 현재 schema 2에서는 덮어쓰지 않고 실패한다. 초안 생성기로 현재 manifest를 되돌리지 않는다.

## 실제 호출 전에 확인받을 계획

2026-10-27 공식 사양 기준. 두 계획은 독립 실행이며 자동으로 연속 실행하거나 재시도하지 않는다.
`--live`와 현재 계획의 `--approved-plan=<fingerprint>`가 모두 있어야 실행된다.
fingerprint는 모델·수량·설정·manifest bytes에 묶인다. 체크아웃 줄바꿈이 바뀌어도 다시 생성해 확인한다.
flag는 승인 내용을 고정하는 도구이며 사람이 승인한 사실을 대신하지 않는다.

| 계획 | 전송 자료와 모델 | 최대 요청 | 예상 비용 USD |
| --- | --- | --- | --- |
| A: OpenAI ASR + OpenAI 검사 | 합성 M4A 8개를 로컬 WAV로 변환 → `gpt-transcribe` 8회, 이미지 10개를 PNG로 정규화 → `omni-moderation-latest` 10회, 실제 추출 텍스트 최대 16회 moderation | 34회 | $0.009 |
| B: OpenAI ASR + Cloudflare 텍스트 비교 | 같은 음성의 OpenAI ASR 최대 8회, 실제 OCR/ASR 텍스트 최대 16회 → `@cf/meta/llama-guard-3-8b`. Cloudflare에 이미지·원음은 전송하지 않음 | 24회 | $0.01680544 |
| 두 계획 모두 별도 승인 | ASR 재사용 캐시 없이 각각 실행. 최대 음성 4분·이미지 10개·텍스트 32회 | 58회 | $0.02580544 |

ASR 예산은 파일당 15초 × 8 = 2분, [공식 추정 단가](https://developers.openai.com/api/docs/pricing)
$0.0045/분을 사용한다. moderation은 무료다. 현재 모델은
[공식 전사 가이드](https://developers.openai.com/api/docs/guides/speech-to-text)의 `gpt-transcribe`다.
이전 계획의 deprecated 후보 `gpt-4o-mini-transcribe`로 자동 대체하지 않는다.
Cloudflare는 [공식 가격](https://developers.cloudflare.com/workers-ai/platform/pricing/)의
입력 $0.484/백만·출력 $0.030/백만 토큰, 회당 입력 1,000·출력 128토큰 가정이다.
출력은 128로 제한하지만 입력 토큰·계정 잔여량·세금은 확정하지 않았으므로 금액은 청구 상한 보장이 아니다.
계정의 실제 접근 권한·잔여량은 호출하지 않고 아직 미확인이다.

파일당 20 MiB·15초, 사례당 30초, 네이티브 작업당 20초, 재시도 0회.
첫 비정상 HTTP/전송 실패에서 전체 요청을 중단한다. 401/403/429/5xx를 성공으로 처리하지 않는다.
사전 무결성·정상 파일 디코딩·OCR/VAD 실행을 확인한 뒤에만 외부 호출 경로로 진입한다.
손상/미지원 파일과 무음/잡음 대조군은 ASR에 보내지 않는다.
B는 이미지 자체를 검사할 수 없어 이미지 전체 결과가 항상 unavailable이고 텍스트 부분 결과만 비교한다.
CF Whisper·외부 vision OCR은 이번 도구에 연결하지 않았으며 호출 수에 포함하지 않는다.

계획 A fingerprint: `4647dd3081de7964e824bb1afcb86653bfb5795ce6e9522fecbe11ea03dbc355`.
계획 B fingerprint: `c08df2064be8028d4381bcb67295c0c88fd36f3708ae03f1520e973200a29877`.
기준 manifest SHA-256: `cbe894e09e2112d424966bfc8f831a0d1cf96da6867f72ea267f79c95e687590`.

실제 OpenAI 호출에는 유효한 `CONTENT_SAFETY_OPENAI_API_KEY`가 필요하다.
하루 만료로 발급했다면 만료 뒤 새 키가 필요하며 이번에는 유효성 확인 요청도 하지 않았다.
키는 기존 무시된 로컬 파일에만 저장하고 화면·채팅·보고서에 붙여넣지 않는다.
호출 도구는 env 파일을 자동 탐색하지 않으므로 승인 뒤 해당 Node 프로세스에서만 안전하게 읽는다.
텍스트 분류만 Cloudflare로 바꾸어도 계획 B의 OpenAI ASR에는 OpenAI 키가 필요하다.

로컬 OCR/VAD/Vosk 단계는 외부 전송이 없다. 승인된 계획은 위 OpenAI/Cloudflare endpoint로만 합성 자료를 전송한다.
OpenAI의 endpoint별 보관 조건은 [공식 데이터 제어 표](https://developers.openai.com/api/docs/guides/your-data),
Cloudflare는 [Workers AI 데이터 사용](https://developers.cloudflare.com/workers-ai/platform/data-usage/)을 따른다.
OpenAI 전사/moderation의 기본 표상 학습·abuse monitoring·application state 보관은 없음이다.
이미지 안전 예외, 계정별 지역/계약 및 Gateway의 별도 기록 설정을 같다고 가정하지 않는다.
원문 대신 해시·판정·상태·지연·CER만 결과에 저장한다. 실제 호출 지연·비용은 아직 측정하지 않았다.

## 남은 검증과 다음 구현

AI API 회귀 413개와 Python 코덱 테스트 8개를 통과했다. 실패 테스트를 먼저 커밋했고
어댑터·CLI·프로세스 격리·취소·실제 코덱을 별도로 검증했다. 유료 live CLI 경로의 end-to-end는 아직 실행하지 않았다.
Node coverage는 전체 로드 파일(테스트 포함) line 93.95% / branch 86.50%다.
추출 어댑터는 100% / 89.47%, OpenAI ASR 어댑터는 100% / 90.91%, native wrapper는 92.68% / 79.31%다.
실행 CLI는 승인 거부·plan 경로만 자동 테스트해 40.74% / 33.33%이며 유료 경로까지 검증한 수치로 해석하지 않는다.
Flutter/iOS 빌드와 운영 RLS 검증은 이번 변경의 검증에 포함하지 않는다.

사람의 8개 청취 → 승인된 실제 ASR/OCR·후단 분류 측정 → 부정어/위협어 보존·오허용·오차단·판정 불가,
단계별 p50/p95·실제 청구량을 분리해 비교한다. 청취에서 대본과 다르면 fixture를 수정하고 해시·계획부터 다시 확인한다.
단일 TTS 화자·인쇄 글 위주이며 사진·손글씨·실제 녹음·비언어적 위험 품질은 여전히 미검증이다.
DB/Storage 공개 차단 경로와 검증 항목은 [기존 설계](content-safety-media-evaluation-plan.md)를 따른다.
해당 제품 연결·운영 변경·배포는 별도 작업과 승인 대상이다.
