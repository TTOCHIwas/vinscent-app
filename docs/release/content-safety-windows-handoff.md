# Windows/Mac 인계: 콘텐츠 검사 평가 준비

갱신일: 2026-10-27.

## 브랜치와 승인 범위

- 저장소: `TTOCHIwas/vinscent-app`
- 브랜치: `codex/content-safety-foundation`. main에 merge하지 않는다.
- 원래 작업 시작: `d3010e95c4715d00353b2205dc8995776146d0fe`
- Windows 텍스트 실측 기준: `95a1154c323d4460d5ef15053dfdaba814a4796c`
- 미디어 준비 RED 테스트: `f6d06549`, GREEN 구현: `bc67cebe`
- 무음 환각 전사의 추가 RED: `3c43d2af`, 음성 감지 확인 GREEN: `6b9512bf`
- 실제 미디어 RED/회귀 테스트: `487c090b`, `f7a8b371`, `61601d8b`, `8498b406`, `9237b405`, `a5cc0129`.
- 실제 어댑터·코덱·합성 발화 구현: `1ac8163b`. 문서는 별도 후속 docs 커밋이다.
- 실제 인계 checkout은 위 커밋들이 포함된 원격 브랜치 최신 HEAD를 사용한다.
- 이번 승인 범위: 실제 발화 8개·OCR/ASR/VAD 평가 도구·앱 코덱 검증, 결과 문서 보존,
  테스트·구현·문서 커밋 분리와 기존 브랜치 push.
- 새 유료 API 평가 호출은 수량·예상 비용을 먼저 제시한다. 이번 미디어 준비의 호출은 0건이다.
- 운영 DB/Storage 변경, Edge Function 배포, 앱 배포·TestFlight는 이번 범위에 포함하지 않는다.

## 먼저 읽을 문서

1. `docs/code-architecture-and-verification.md`
2. `docs/content-safety-publication-design.md`
3. [텍스트 실측 결과](content-safety-evaluation-2026-10-25/README.md)
4. [미디어 설계·비용·DB 차단 검증 계획](content-safety-media-evaluation-plan.md)
5. [현재 실제 미디어 평가 준비](content-safety-media-live-readiness.md), [사람 청취표](content-safety-speech-review.md)
6. `services/ai-api/README.md`, `eval/fixtures/media-ko/README.md`, 적용되는 AGENTS 지침

책임 경계를 보존한다. 이번 미디어 도구는 eval에만 있고 기존 `CheckSharedContent`와 저장 caller의
운영 동작을 바꾸지 않았다. 실패 테스트를 먼저 실행했고 별도 테스트·구현 커밋을 남겼다.
새 로컬 값과 기존 사용자 변경을 보존한다.

## 완료한 측정과 한계

2026-10-25 23:12 KST Windows, Node v22.19.0에서 합성 한국어 18개를 후보별 한 번씩 호출했다.
OpenAI `omni-moderation-latest`, Cloudflare `@cf/meta/llama-guard-3-8b` 모두 기대 판정 18/18,
오허용·오차단·판정 불가 0개, HTTP 200 18/18이다. p50/p95는 각각 527/1,421 ms, 299/694 ms다.
원문 없는 JSON 두 개를 docs/release에 보존했다. 실제 snapshot은 수집하지 않아 설정 모델만 기록했다.
초안 라벨·작은 표본·한 번의 고정 순서 실행이다. 한국어 전체 품질이나 이미지·음성 품질,
운영 공급자 선정의 증거로 확대 해석하지 않는다.

미디어 준비는 합성 24개 사례(이미지 12/음성 12), 원본 변형 10개·손상 코덱 대조군 3개다.
SAPI 외 Windows OneCore를 확인해 Heami 한국어 발화 WAV/M4A 8개를 생성했다. pending 파일은 0개다.
정상 JPEG/WebP/M4A와 손상본·길이 초과를 실제 디코딩했다. OCR 10/10 정규화 일치,
발화 VAD 8/8 감지·무음/잡음 2/2 미감지, 로컬 Vosk 대본 정규화 일치 1/8이다.
사람 청취는 0/8이다. 기술 실행 통과와 자동 품질 미통과를 구분해 JSON에 보존했다.
기하 그림은 사진 데이터가 아니다. 손글씨·합성 사진·다양한 화자 등은 추가 준비 대상이다.

미디어 평가 조합은 port를 주입받는다. 이미지 판정과 OCR/text를 함께 확인하고,
음성 감지·완전한 한국어 전사·텍스트 판정을 요구한다. 빈/부분/실패 전사·미지원·timeout·
잘못된 판정은 unavailable이다. 음성의 allow도 전사된 말의 검사이며 원음 전체 승인이 아니다.
실제 Windows OCR·Silero VAD·로컬 Vosk/OpenAI ASR 어댑터는 eval 도구에만 연결했다.
production VAD·저장/공개 gateway는 연결하지 않았다. 유료 미디어 호출은 실행하지 않았다.

**게시 전 필터링 전체는 미완료다.** 실제 DB 승인·Storage RLS·앱/위젯 공개 경계가 없다.
멤버십/경로 기반 Storage 읽기, 직접 테이블 조회, signed URL·캐시·알림·Realtime까지
함께 검증해야 한다. 최신 SQL wrapper와 helper 재정의 위치는 미디어 계획에 기록했다.

## 받는 환경에서의 명령

실제 저장소 위치와 기존 변경부터 확인한다. checkout/reset/자동 stash로 덮지 않는다.
변경이 있으면 별도 충돌 없는 worktree에서 진행한다. 분기 시 force/reset하지 않는다.

```powershell
git status --short --branch
git fetch origin codex/content-safety-foundation
# 로컬 브랜치가 없고 checkout이 안전할 때
git switch --track origin/codex/content-safety-foundation
# 이미 작업 브랜치라면 상태 확인 후
git pull --ff-only
cd services/ai-api
npm.cmd test
npm.cmd run --silent eval:content-safety-media
npm.cmd run --silent eval:content-safety-media -- --validate-assets
npm.cmd run --silent eval:media -- --provider=openai --asr=openai
```

Mac에서는 `npm.cmd` 대신 `npm`을 사용한다. 기존 Node >=22.6.0 환경을 사용한다.
준비 CLI는 --live를 거부한다. 새 `eval:media`도 기본은 요청 0건의 계획 출력이다.
승인된 fingerprint와 --live를 모두 지정해야 외부 호출한다. Windows OCR/TTS 실행에는
Windows 언어팩과 별도 Python 환경이 필요하며 설치·모델 해시는 현재 준비 문서를 따른다.
기존 텍스트 실측을 재실행할 필요는 없다. 검증 명령을 라이브 품질 평가로 보고하지 않는다.

## 비밀값

키 파일은 Git에 포함하지 않으며 Mac으로 전달하지 않는다. Windows 원래 workspace의
로컬 설정은 기존 내용을 보존했다. 값·원문·인증 파일을 화면/로그/보고서에 출력하지 않는다.
환경 위치가 필요하면 값 대신 경로만 묻는다. Supabase Secrets 원문을 꺼내거나
평가를 위해 운영 함수·Secrets를 변경하지 않는다.

라이브 텍스트 도구의 변수명은 `CONTENT_SAFETY_OPENAI_API_KEY`,
`CONTENT_SAFETY_CLOUDFLARE_ACCOUNT_ID`, `CONTENT_SAFETY_CLOUDFLARE_API_TOKEN`이다.
미디어 도구는 env 파일을 자동으로 읽지 않는다. 로컬 검증에는 키가 필요 없다.
OpenAI 실제 평가에는 유효한 키가 필요하다. 하루 만료 설정이었다면 만료 뒤 갱신한다.
이번에는 키 원문·유효성·계정 잔여량을 조회하지 않았다.

## 이번 검증과 다음 단계

- AI API 회귀: 413개 통과(이전 366 + 신규 47), 실패/건너뜀 0. Python 실제 코덱 테스트 8개 통과.
- 준비 자산 24개 SHA-256·pending 0, 별도 실제 파일 27개 디코딩/OCR/VAD/ASR 자동 검증.
- 원본 변형·손상 코덱 대조군을 포함한 37개 파일 SHA-256 확인. 키 파일·모델·가상 환경은 제외.
- 어댑터 오류·부분/혼합언어 전사·VAD NaN·시간 초과·호출 상한·HTTP 실패 중단·자식 프로세스 키 배제 테스트.
- 외부 미디어 평가·사람 청취, Flutter/iOS 빌드와 운영 DB/RLS 검증은
  하지 않았다. 별도 TypeScript compiler/build/lint 스크립트는 서비스에 없다.
- 원문·키 미포함, 변경 파일·diff와 기존 main/로컬 상태를 확인한 뒤 push한다.

다음은 사람의 8개 청취 검토와 승인된 실제 외부 평가다. 현재 계획 A는 OpenAI ASR+검사
최대 34회·$0.009 추정, B는 OpenAI ASR+Cloudflare 텍스트 비교 최대 24회·$0.01680544 추정이다.
두 계획 별도 실행 시 최대 58회·$0.02580544이며 비용 가정·전송 자료·보관 조건은 현재 준비 문서에 있다.
Cloudflare 이미지 자체 판정은 지원하지 않아 전체 이미지 결과는 unavailable이다.
계정 접근·유효한 키·잔여량을 승인 후 확인한다. 로컬 ASR 1/8만으로 운영 공급자를 정하지 않는다.
이후 로컬 SQL RED 테스트부터 DB/Storage
원자적 승인·공개 경계, 모바일·위젯 실패 UX를 구현하고 Mac/Xcode·실기기로 검증한다.
운영 반영과 앱 배포는 별도 승인 후 진행한다.
