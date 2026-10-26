# Windows/Mac 인계: 콘텐츠 검사 평가 준비

갱신일: 2026-10-26.

## 브랜치와 승인 범위

- 저장소: `TTOCHIwas/vinscent-app`
- 브랜치: `codex/content-safety-foundation`. main에 merge하지 않는다.
- 원래 작업 시작: `d3010e95c4715d00353b2205dc8995776146d0fe`
- Windows 텍스트 실측 기준: `95a1154c323d4460d5ef15053dfdaba814a4796c`
- 미디어 준비 RED 테스트: `f6d06549`, GREEN 구현: `bc67cebe`
- 무음 환각 전사의 추가 RED: `3c43d2af`, 음성 감지 확인 GREEN: `6b9512bf`
- 실제 인계 checkout은 위 커밋들이 포함된 원격 브랜치 최신 HEAD를 사용한다.
- 이번 승인 범위: 이미지·음성 설계, 합성 평가 준비, 결과 문서 보존,
  테스트·구현·문서 커밋 분리와 기존 브랜치 push.
- 새 유료 API 평가 호출은 수량·예상 비용을 먼저 제시한다. 이번 미디어 준비의 호출은 0건이다.
- 운영 DB/Storage 변경, Edge Function 배포, 앱 배포·TestFlight는 이번 범위에 포함하지 않는다.

## 먼저 읽을 문서

1. `docs/code-architecture-and-verification.md`
2. `docs/content-safety-publication-design.md`
3. [텍스트 실측 결과](content-safety-evaluation-2026-10-25/README.md)
4. [미디어 설계·비용·DB 차단 검증 계획](content-safety-media-evaluation-plan.md)
5. `services/ai-api/README.md`, `eval/fixtures/media-ko/README.md`, 적용되는 AGENTS 지침

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

미디어 준비는 합성 24개 사례(이미지 12/음성 12), 생성 파일 16개와 한국어 발화 대본 8개다.
한국어 TTS가 없는 Windows 환경이라 발화 파일은 아직 없으며 manifest에 pending으로 표시했다.
기하 그림은 사진 데이터가 아니다. 손글씨·합성 사진·음성 코덱·다양한 화자 등은 추가 준비 대상이다.
자산 무결성 검증 통과를 모델 품질 통과로 보고하지 않는다.

미디어 평가 조합은 port를 주입받는다. 이미지 판정과 OCR/text를 함께 확인하고,
음성 감지·완전한 한국어 전사·텍스트 판정을 요구한다. 빈/부분/실패 전사·미지원·timeout·
잘못된 판정은 unavailable이다. 음성의 allow도 전사된 말의 검사이며 원음 전체 승인이 아니다.
실제 OCR/ASR adapter, production VAD와 공개 gateway는 아직 연결하지 않았다.

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
```

Mac에서는 `npm.cmd` 대신 `npm`을 사용한다. 기존 Node >=22.6.0 환경을 사용하며 패키지 추가는 없다.
미디어 CLI는 plan/asset validation만 제공하고 --live를 거부한다. 기본 텍스트 CLI도 plan은 요청 0건이다.
기존 텍스트 실측을 재실행할 필요는 없다. 검증 명령을 라이브 품질 평가로 보고하지 않는다.

## 비밀값

키 파일은 Git에 포함하지 않으며 Mac으로 전달하지 않는다. Windows 원래 workspace의
로컬 설정은 기존 내용을 보존했다. 값·원문·인증 파일을 화면/로그/보고서에 출력하지 않는다.
환경 위치가 필요하면 값 대신 경로만 묻는다. Supabase Secrets 원문을 꺼내거나
평가를 위해 운영 함수·Secrets를 변경하지 않는다.

라이브 텍스트 도구의 변수명은 `CONTENT_SAFETY_OPENAI_API_KEY`,
`CONTENT_SAFETY_CLOUDFLARE_ACCOUNT_ID`, `CONTENT_SAFETY_CLOUDFLARE_API_TOKEN`이다.
미디어 준비 CLI는 키를 요구하거나 자동으로 env 파일을 읽지 않는다.

## 이번 검증과 다음 단계

- AI API 회귀: 366개 통과(기존 332 + 신규 34), 실패/건너뜀 0.
- 신규 도구의 offline plan, 미지원 live 인자 거부, 자산 16개 SHA-256·8개 pending 확인.
- 새 평가 조합 line/branch coverage 100%/98.88%, CLI 92.31%/64.29%.
  두 신규 테스트 타깃의 전체 line/branch coverage는 95.43%/96.32%이며 전체 서비스 coverage는 아니다.
- 생성 PNG의 한글 렌더 확인. 이미지/음성 외부 품질 평가, Flutter/iOS 빌드와 운영 DB/RLS 검증은
  하지 않았다. 별도 TypeScript compiler/build/lint 스크립트는 서비스에 없다.
- 원문·키 미포함, 변경 파일·diff와 기존 main/로컬 상태를 확인한 뒤 push한다.

다음은 한국어 음성 파일 제작·라벨 검토, 합성 사진/손글씨 등 누락 자료 준비,
OCR/ASR·VAD adapter 구성과 실제 호출 전 비용/보관 조건 확인이다.
기본 smoke 예산은 최대 80회, 약 $0.03 수준의 가정이며 최종 견적이 아니다.
모델 가용성·분량·계정 잔여량을 재확인한다. 이후 로컬 SQL RED 테스트부터 DB/Storage
원자적 승인·공개 경계, 모바일·위젯 실패 UX를 구현하고 Mac/Xcode·실기기로 검증한다.
운영 반영과 앱 배포는 별도 승인 후 진행한다.
