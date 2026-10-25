# Windows 인계: 공유 콘텐츠 검사 후보 평가

작성일: 2026-10-25.

## 목적과 사용자 결정

Apple 정식 출시 준비를 항목별로 진행한다. 첫 작업은 공유 콘텐츠 게시 전 검사다.
사용자는 기존 공급자 유지보다 검사 품질과 한국어 지원을 비교해 적합한 서비스를
선정하도록 요청했다. API 키가 있는 Windows 노트북에서 평가를 이어간다.

- 저장소: `TTOCHIwas/vinscent-app`
- 작업 브랜치: `codex/content-safety-foundation`
- 작업 시작 기준: `d3010e95c4715d00353b2205dc8995776146d0fe`
- 구현·설계 기준: `ff66c4e7a4043281a6bc91b3f2630b51a9f6f3bb`
- 이 문서는 위 기준 이후 추가된 인계 문서다. 실제 체크아웃은 원격 작업 브랜치의
  최신 커밋을 사용한다.
- 사용자는 이 브랜치를 GitHub에 push해 Windows에서 이어가도록 승인했다.
  운영 DB 변경, 출시 workflow, TestFlight 업로드는 별도 명시적 승인 대상이다.

## 먼저 읽을 문서

1. `docs/code-architecture-and-verification.md`
2. `docs/content-safety-publication-design.md`
3. `services/ai-api/README.md`
4. 적용되는 `AGENTS.md`가 있으면 해당 지침을 함께 따른다.

실패하는 테스트를 먼저 확인하고 테스트·구현 커밋을 분리한다. domain은 순수 정책,
application은 처리 흐름과 port, infrastructure는 외부 I/O를 담당한다. 중요한
공개 정책은 서버에서 강제한다. 기존 사용자 변경과 로컬 비밀값을 보존한다.

## 브랜치 받기

Windows의 실제 Git 저장소를 먼저 확인한다. 경로를 `D:\vinscent`로 가정하지 않는다.
현재 변경사항이 있으면 checkout·reset·자동 stash로 덮지 않고 별도 작업 디렉터리
또는 충돌 없는 경로에서 진행한다. `main`에 merge하지 않는다.

```powershell
git status --short --branch
git fetch origin
```

로컬 작업 브랜치가 아직 없으면:

```powershell
git switch --track origin/codex/content-safety-foundation
```

이미 같은 로컬 브랜치가 있으면 변경사항과 분기 상태를 확인한 뒤:

```powershell
git switch codex/content-safety-foundation
git pull --ff-only
```

분기가 갈라졌다면 force/reset하지 말고 원인을 확인한다. Git bundle 파일은 필요 없다.

## 완료된 범위와 검증 한계

- 검사 값·계약, `CheckSharedContent` 유스케이스와 OpenAI/Cloudflare 후보 어댑터 구현.
- 잘린 분류 응답·모호한 판정·HTTP 오류·시간 초과·지원하지 않는 음성을 승인하지 않음.
- 한국어 합성 텍스트 18개와 오허용·오차단·판정 불가·p50/p95 집계 도구 준비.
- 신규 테스트 49개를 포함한 AI 서비스 전체 332개 테스트가 Mac에서 통과.
- 비밀정보 검사 통과. Mac에서 실제 공급자 API 호출은 하지 않음.

**게시 전 필터링 전체는 미완료다.** 공급자 미선정, 한국어 실측 미수행, 이미지·음성
품질 미평가 상태다. DB gateway·공개 승인·Storage RLS·앱/위젯 저장 경로에 연결하지
않았다. 단위 테스트의 stale 결과 처리는 실제 DB의 원자적 공개 차단을 입증하지 않는다.
기존 저장·공개 동작은 유지되고 있으며 운영 DB나 앱 배포를 수행하지 않았다.

## Windows에서 이어갈 순서

### 1. 기존 테스트와 실행 환경 확인

Node 요구 버전은 `services/ai-api/package.json`을 확인한다. 별도의 패키지 추가 없이
현재 프로젝트의 Node 실행 환경을 사용한다. PowerShell에서는 `npm.cmd`를 쓰면
`npm.ps1` 실행 정책과 혼동하지 않을 수 있다.

```powershell
Set-Location services/ai-api
node --version
npm.cmd test
npm.cmd run eval:content-safety
```

기본 평가 실행은 외부 요청 0건의 계획 출력이다. 이 결과를 모델 품질 평가로
보고하지 않는다.

### 2. 기존 키를 평가 전용 환경변수에 연결

| 후보 | 평가 도구가 읽는 환경변수 |
| --- | --- |
| OpenAI | `CONTENT_SAFETY_OPENAI_API_KEY` |
| Cloudflare | `CONTENT_SAFETY_CLOUDFLARE_ACCOUNT_ID`, `CONTENT_SAFETY_CLOUDFLARE_API_TOKEN` |

먼저 기존 프로세스 환경변수나 사용자가 알려 준 보안 설정 위치를 확인한다. 키 값은
화면·채팅·로그·보고서·커밋에 출력하지 않는다. `.env`나 인증 파일을 검색 결과에
덤프하지 않는다. 설정 위치가 불분명하면 키 내용 대신 위치만 물어본다. 기존 운영
파일을 수정하거나 덮어쓰지 않고 평가 프로세스에 필요한 변수만 연결한다.

CLI는 `.env`를 자동으로 읽지 않는다. `OPENAI_API_KEY` 같은 기존 이름만 설정돼
있다면 평가 전용 이름으로 값을 연결해야 한다. 키 부재 시 운영 서비스나 GitHub
secrets를 무단으로 추출하지 않고 필요한 보안 설정을 안내한다.

### 3. 합성 한국어 텍스트 평가

```powershell
npm.cmd run --silent eval:content-safety -- --live --provider=openai
npm.cmd run --silent eval:content-safety -- --live --provider=cloudflare
```

각 후보는 합성 문장 18개를 순서대로 요청하며 자동 재시도하지 않는다. 실제 사용자
질문·답변·사진·녹음을 평가 데이터로 사용하지 않는다. Cloudflare 호출에는 해당
계정의 사용량/요금이 적용될 수 있다. 실행 전에 공식 사양과 평가 계정의 한도를
확인하고 반복 횟수를 무제한으로 늘리지 않는다.

오허용·오차단·판정 불가가 있으면 종료 코드 1을 반환한다. 따라서 종료 코드 1만으로
도구 고장이라고 판단하지 말고 JSON 결과를 확인한다. 키·권한·호출 제한·네트워크
문제를 한국어 품질 실패와 구분한다. 오류 본문에 원문이나 인증 정보가 포함될 수
있으므로 공급자 원본 응답을 로그에 추가하지 않는다.

### 4. 결과 검토와 후속 작업

평가 결과는 원문 없이 후보·실행일·설정 모델·예시 ID·기대/실제 판정·오차단·오허용·
판정 불가·지연 시간으로 정리한다. 모든 후보의 입력·라벨·실행 조건을 동일하게
유지한다. 관용구와 정상 갈등 표현이 과차단되는지, 위협이 누락되는지 검토한다.
라벨은 검토용 초안이며 18개 결과를 한국어 전체 품질 보증으로 해석하지 않는다.

OpenAI는 현재 텍스트·이미지 후보이고 음성을 직접 검사하지 않는다. Cloudflare
Llama Guard 후보는 텍스트 전용이며 공식 지원 언어 목록에 한국어가 없다. 실제
결과 없이 우열을 확정하지 않는다. 이미지 속 글, 이미지의 지원되지 않는 분류,
전사 실패·침묵·잡음 등도 별도 평가한다. 새로운 외부 처리자와 사진·음성 전송이
필요하면 개인정보·동의·보관 조건을 실제 경로와 함께 검토한다.

공급자 평가 후에는 설계 문서의 순서대로 DB/Storage 공개 경계의 RED 테스트,
서버 구현, 모바일·위젯 저장 흐름과 실패 UX, 정책·동의 안내, 실기기 검증을 진행한다.

## 인계 결과 보고

- 체크아웃 브랜치와 HEAD
- Windows 테스트 결과와 기존 변경 보존 여부
- 후보별 텍스트 평가 수치와 실패 원인 구분
- 이미지·음성 및 공급자 선정의 남은 판단
- 다음 구현 범위와 운영 반영 여부

검사 기반이나 텍스트 평가가 끝났다는 이유로 Apple 출시 차단 항목 전체가 해결됐다고
보고하지 않는다.
