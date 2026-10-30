# Windows/Mac 인계: 콘텐츠 검사 평가 준비

갱신일: 2026-10-29.

## 브랜치와 승인 범위

- 저장소: `TTOCHIwas/vinscent-app`
- 브랜치: `codex/content-safety-foundation`. main에 merge하지 않는다.
- 원래 작업 시작: `d3010e95c4715d00353b2205dc8995776146d0fe`
- Windows 텍스트 실측 기준: `95a1154c323d4460d5ef15053dfdaba814a4796c`
- 미디어 준비 RED 테스트: `f6d06549`, GREEN 구현: `bc67cebe`
- 무음 환각 전사의 추가 RED: `3c43d2af`, 음성 감지 확인 GREEN: `6b9512bf`
- 실제 미디어 RED/회귀 테스트: `487c090b`, `f7a8b371`, `61601d8b`, `8498b406`, `9237b405`, `a5cc0129`.
- 실제 어댑터·코덱·합성 발화 구현: `1ac8163b`. 문서는 별도 후속 docs 커밋이다.
- 문맥·청취 증거 검토 RED: `986f978b`, `0ba62f25`, `e32dfd75`; GREEN: `b7381b3b`.
- 문맥 후보 RED: `6a6ed379`, `0fa5c642`; GREEN: `5f9b50d6`.
- 실제 인계 checkout은 위 커밋들이 포함된 원격 브랜치 최신 HEAD를 사용한다.
- 이번 승인 범위: 실제 발화 8개·OCR/ASR/VAD 평가 도구·앱 코덱 검증, 결과 문서 보존,
  테스트·구현·문서 커밋 분리와 기존 브랜치 push.
- 새 유료 API 평가 호출은 수량·예상 비용을 먼저 제시한다. 사용자가 승인한 OpenAI 계획 A만
  2026-10-29 1회 실행했다. 실제 요청 34회이며 Cloudflare 계획 B는 실행하지 않았다.
- 이후 2026-10-30 별도 승인한 Luna/Terra 문맥 both 계획 24회를 1회 실행했다.
  두 후보 모두 초안 10/10 일치, 미정 2개 unavailable이다. 추가 반복 호출은 승인하지 않았다.
- 운영 DB/Storage 변경, Edge Function 배포, 앱 배포·TestFlight는 이번 범위에 포함하지 않는다.

## 먼저 읽을 문서

1. `docs/code-architecture-and-verification.md`
2. `docs/content-safety-publication-design.md`
3. [텍스트 실측 결과](content-safety-evaluation-2026-10-25/README.md)
4. [미디어 설계·비용·DB 차단 검증 계획](content-safety-media-evaluation-plan.md)
5. [현재 실제 미디어 평가 준비](content-safety-media-live-readiness.md), [사람 청취표](content-safety-speech-review.md)
6. [OpenAI 미디어 실측 결과](content-safety-media-evaluation-2026-10-29/README.md)
7. [강요·금지 맥락 자동 검토](content-safety-context-policy-review-2026-10-29/README.md)
8. [문맥 분류 후보와 호출 전 계획](content-safety-context-candidate-readiness-2026-10-29/README.md)
9. [문맥 후보 실제 평가](content-safety-context-evaluation-2026-10-30/README.md)
10. [피해 진술·인용 제안과 확장 표본](content-safety-context-expansion-2026-10-30/README.md)
11. [v2 어댑터와 호출 전 계획](content-safety-context-v2-readiness-2026-10-30/README.md)
12. `services/ai-api/README.md`, `eval/fixtures/media-ko/README.md`, 적용되는 AGENTS 지침

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
2026-10-29 OpenAI ASR은 같은 발화 8개에서 CER 0을 확인했지만 사람 청취는 미완료다.
미디어 안전 판정은 전체 20/24, 대조군을 뺀 14/18 기대 일치다. 강요 오허용 2·금지 맥락 오차단 2다.
네 오류 모두 추출 CER 0이며 텍스트 moderation에서 기대와 다른 판정을 확인했다.
production VAD·저장/공개 gateway는 연결하지 않았다. 정책을 바꾸거나 추가 유료 재시도를 하지 않았다.

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
npm.cmd run --silent eval:policy-review
npm.cmd run --silent eval:context
npm.cmd run --silent eval:context-expansion
npm.cmd run --silent eval:context-expansion-live
```

Mac에서는 `npm.cmd` 대신 `npm`을 사용한다. 기존 Node >=22.6.0 환경을 사용한다.
준비 CLI는 --live를 거부한다. 새 `eval:media`도 기본은 요청 0건의 계획 출력이다.
승인된 fingerprint와 --live를 모두 지정해야 외부 호출한다. Windows OCR/TTS 실행에는
Windows 언어팩과 별도 Python 환경이 필요하며 설치·모델 해시는 현재 준비 문서를 따른다.
기존 텍스트 실측을 재실행할 필요는 없다. 검증 명령을 라이브 품질 평가로 보고하지 않는다.
`eval:policy-review`는 외부 요청 없이 기존 실측의 품질 불일치와 청취 대기를 재현하며 현재 종료 코드는 1이다.
`eval:context`도 기본은 요청 0건인 계획 출력이다. 문맥 후보 both 계획은 2026-10-30 승인받아 24회 완료했다.
기존 실행을 재현한다며 추가 라이브 호출하지 않는다. 추가 호출은 새 비용·수량 승인 후 진행한다.

## 비밀값

키 파일은 Git에 포함하지 않으며 Mac으로 전달하지 않는다. Windows 원래 workspace의
로컬 설정은 기존 내용을 보존했다. 값·원문·인증 파일을 화면/로그/보고서에 출력하지 않는다.
환경 위치가 필요하면 값 대신 경로만 묻는다. Supabase Secrets 원문을 꺼내거나
평가를 위해 운영 함수·Secrets를 변경하지 않는다.

라이브 텍스트 도구의 변수명은 `CONTENT_SAFETY_OPENAI_API_KEY`,
`CONTENT_SAFETY_CLOUDFLARE_ACCOUNT_ID`, `CONTENT_SAFETY_CLOUDFLARE_API_TOKEN`이다.
미디어 도구는 env 파일을 자동으로 읽지 않는다. 로컬 검증에는 키가 필요 없다.
OpenAI 실제 평가에는 유효한 키가 필요하다. 하루 만료 설정이었다면 만료 뒤 갱신한다.
2026-10-29에는 새 키를 평가 프로세스에만 로드했고 승인된 34회가 모두 HTTP 200이었다.
키 값·인증 파일은 출력/커밋하지 않았다. 계정의 잔여량과 실제 청구액은 조회하지 않았다.
2026-10-30 문맥 후보 실행에도 기존 키를 프로세스에만 로드했고 HTTP 200 24/24였다.

## 이번 검증과 다음 단계

- AI API 회귀: 525개 통과(확장 검토까지 497 + v2 평가 28), 실패/건너뜀 0.
  Python 코덱 8개 통과는 이전 미디어 실측 준비 기록이며 이번에는 해당 구현을 변경하지 않았다.
- 준비 자산 24개 SHA-256·pending 0, 별도 실제 파일 27개 디코딩/OCR/VAD/ASR 자동 검증.
- 원본 변형·손상 코덱 대조군을 포함한 37개 파일 SHA-256 확인. 키 파일·모델·가상 환경은 제외.
- 어댑터 오류·부분/혼합언어 전사·VAD NaN·시간 초과·호출 상한·HTTP 실패 중단·자식 프로세스 키 배제 테스트.
- 외부 미디어 평가: 계획 A 34/34 HTTP 200, 24사례 완료. 품질 불일치 4건으로 CLI exit 1.
  무음·잡음·손상/미지원 6건은 모두 unavailable, 자동 허용 0건이다.
- 전체 사례 p50/p95 1,720/2,744 ms, 정상 안전 판정 대상 18개만 1,938/3,685 ms.
  사전 준비 시간은 제외했으며 원문 전사·model snapshot·개별 단계 지연은 저장하지 않았다.
- 사람 청취, Flutter/iOS 빌드와 운영 DB/RLS 검증은 하지 않았다.
  별도 TypeScript compiler/build/lint 스크립트는 서비스에 없다.
- 원문·키 미포함, 변경 파일·diff와 기존 main/로컬 상태를 확인한 뒤 push한다.

사용자 지정에 따라 사람의 8개 청취는 미완료로 유지하고 자동 검토부터 수행했다.
강요 차단·위해 금지 허용의 기존 기준을 보존하고 12개 문맥 대조문을 모두 초안으로 준비했다.
피해 진술·인용 2개는 기존 제품 기준이 없어 미정으로 남겼다. 오프라인 검토 단계의 유료 요청은 0건이었다.
새 오프라인 도구는 기존 오허용 2·오차단 2를 두 대본의 문제로 재현하며 게시 권한을 부여하지 않는다.
이후 Luna/Terra Responses 문맥 후보를 연결하고 각 12건, 합계 최대 24회 계획을 준비했다.
10개 초안 라벨과 미정 2개는 분리 집계한다. 구현 단계 후보 API 요청은 0건이었다.
이후 약 $0.067·보수적 추정 약 $0.20 조건을 별도 승인받아 2026-10-30 최대 24회를 모두 실행했다.
두 후보 모두 초안 10/10 일치, 미정 2/2 unavailable이며 오류·재시도·추가 호출은 0건이다.
관측 토큰 기반 일반 단가 추정 합계 $0.009204900, cache write 여유 반영 $0.010684125이며 실제 청구액은 미조회다.
Luna p50/p95 1,712/4,364 ms, Terra 2,033/2,781 ms다. 단일 고정 순서 12개 결과로 속도 우위를 확정하지 않는다.
기존 강요·금지 문장의 텍스트 판정은 맞았지만 이미지/음성 전체 조합을 재평가한 것은 아니다.
실행 기준 `dd2dfc4e`, 결과와 후속 범위는 2026-10-30 문맥 실측 보고서를 따른다.
입력·정책·요청 설정 전체와 지문은 현재 후보 준비 문서/JSON을 따른다. 사람 청취는 여전히 미완료다.
계획 A는 34회로 완료됐으며,
전송 음성 26.257초 × 공식 단가 기준 약 $0.00197 추정이다. 실제 청구액은 확인하지 않았다.
추가 Cloudflare 계획 B의 최초 예산은 최대 24회·$0.01680544 추정이고 실행은 별도 확인 후 진행한다.
비용 가정·전송 자료·보관 조건은 준비 문서, 실제 결과와 해석은 새 실측 보고서에 있다.
Cloudflare 이미지 자체 판정은 지원하지 않아 전체 이미지 결과는 unavailable이다.
계정 잔여량은 미확인이다. 로컬 ASR 1/8이나 이번 OpenAI 자동 전사 8/8만으로 운영 공급자를 정하지 않는다.
이후 로컬 SQL RED 테스트부터 DB/Storage
원자적 승인·공개 경계, 모바일·위젯 실패 UX를 구현하고 Mac/Xcode·실기기로 검증한다.
운영 반영과 앱 배포는 별도 승인 후 진행한다.

이전 2026-10-29 작업 종료 때 사용자 승인에 따라 Windows 정상 종료 요청을 처리했다.
2026-10-30에는 문맥 both 계획 평가와 문서 보존을 승인받아 진행했다.
다음은 피해 진술·인용의 제품 기준과 독립 확장 표본 검토, 평가 전용 OCR/ASR 관측문 조합 검증이다.
사람 청취는 사용자 지정대로 0/8 미완료이며 운영 공급자·공개 정책은 미확정이다.

2026-10-30 후속으로 사용자가 공개 자료를 참고한 처리 기준 판단을 위임했다.
피해 진술·도움 요청과 명확한 허구 인용은 문맥상 허용, 직접 위협·강요는 차단, 불충분한 문맥은 보류하는
`ko-context-proposal-v2`를 추가 자료에 기록했다. 제품 정책이나 기존 v1 지시문/실측 라벨은 바꾸지 않았다.
새 합성 28개는 제안 allow 15·block 9·미정 null 4이며 기존 자료의 정규화 문장 중복은 0개다.
같은 에이전트가 작성했으므로 독립 검증 완료 자료가 아니다. 사람 라벨 검토 0/28, 새 모델 평가 0회다.
정책·자료 지문과 문장 해시가 묶인 빈 서식과 오프라인 검토 CLI를 구현했다.
`eval:context-expansion`은 --live를 거부하며 키 파일을 읽지 않는다. 테스트 RED `afaf4185`, `6b50e62c`, GREEN `111587d9`다.
다음은 독립 라벨 검토와 별도 v2 평가 어댑터/호출 계획 준비다. 기존 최대 24회 승인을 재사용하지 않는다.

이후 v2/28문장용 Responses adapter와 별도 CLI를 연결했다. 실제 v2 API 호출과 키 파일 읽기는 0회다.
`eval:context-expansion-live`도 기본은 계획만 출력하며 최대 Luna 28/Terra 28/both 56회다.
both 예상 $0.155848·보수적 추정 $0.463848, 새 지문 `e1d605fa44cca0845fb5fc9aa749736a903ea816d4c99986847c007d37d65ef4`다.
정책·자료·schema·실제 요청 설정·모델·제한·비용 가정을 묶으며 기존 v1 지문과 24회 제한은 보존했다.
초안 라벨 24개와 정답 미정 4개를 분리한다. 새 후보의 실제 품질은 미측정이며 독립 검증·사람 청취는 미완료다.
RED `958fac6e`, 추가 검증 `9272f5bb`, GREEN `59979b48`. 모의 CLI 전체 56회·실패 시 1회 중단을 검증했다.
다음 실제 평가에는 위 새 계획의 전송 자료·모델·수량·비용에 대한 별도 승인이 필요하다.
