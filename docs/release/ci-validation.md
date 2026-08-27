# CI 검증 기준

## 목적

`.github/workflows/ci.yml`은 Pull Request와 `main` 브랜치 변경에서 출시 전
회귀를 검증한다. `.github/ci-paths.yml`로 변경된 구성요소를 분류하고 관련된
검증만 실행한다. `workflow_dispatch` 수동 실행은 경로와 관계없이 모든 검증을
실행한다. 이 워크플로는 원격 Supabase, Play Console, App Store Connect에
배포하지 않으며 배포 비밀키를 사용하지 않는다.

`Change detection` 작업은 모든 실행에서 변경 경로를 분류하고 추적된 비밀값을
검사한다. 기존 필수 체크인 `Node services`는 항상 결과를 남기며 변경 감지
작업이 실패하면 그 실패를 전달한다. 따라서 필터 오류나 비밀값 검사 실패가
조건부 작업의 건너뜀으로 가려지지 않는다.

`.github/workflows/supabase-production.yml`은 CI와 분리된 수동 운영 배포
워크플로다. 정확한 `main` commit과 project ref 확인, GitHub Environment
승인, 동일한 Database·Edge 검증을 모두 통과한 뒤에만 migration과
Edge Function을 배포한다.

`.github/workflows/store-assets.yml`은 출시 후보 화면을 캡처하고 저장소에
추가한 뒤 실행하는 수동 검증 워크플로다. 일반 PR과 출시 후보 빌드를
차단하지 않으며 실제 앱 버전과 빌드 번호를 입력받아 Play·App Store 문구
제한과 스토어 그래픽 자산 계약을 검증한다.

`.github/workflows/ios-release.yml`은 일반 CI와 분리된 수동 iOS 릴리스
워크플로다. `ios-release` Environment 승인과 정확한 `main` commit을 요구하고,
Mac 사전 점검 뒤 서명된 IPA와 검증 증빙을 만든다. 실행자가
`publish_testflight`를 선택한 경우에만 App Store Connect에 업로드한다.

GitHub 문서의 권고에 따라 워크플로 권한은 `contents: read`로 제한하고,
변경 파일 조회가 필요한 작업에만 `pull-requests: read`를 추가한다. 외부
액션은 전체 커밋 SHA로 고정한다.

- [GitHub Actions 보안 사용 지침](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub Actions 작업 조건](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions)
- [dorny/paths-filter](https://github.com/dorny/paths-filter)
- [Flutter 통합 테스트](https://docs.flutter.dev/testing/integration-tests)
- [GitHub-hosted Android 하드웨어 가속](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub macOS 26 runner 이미지](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
- [Supabase 자동화된 데이터베이스 테스트](https://supabase.com/docs/guides/deployment/ci/testing)

## 필수 체크

| 체크 | 자동 PR·`main` | 수동 전체 CI·출시 | 검증 범위 |
|---|---|---|---|
| `Change detection` | 항상 | 항상 | 변경 경로 분류, 추적된 비밀값 검사 |
| `Flutter` | 모바일 관련 변경 | 전체 실행 | 의존성 복원, Dart 표준 포맷, 정적 분석, 전체 Flutter 테스트. 수동 전체 CI에서는 Android 네이티브 테스트와 디버그 APK도 추가 검증 |
| `Android integration` | 건너뜀 | 수동 전체 CI와 Android 출시 | API 36 에뮬레이터에서 프로덕션 진입점 콜드 스타트, Firebase·홈 위젯 플러그인 등록, 백엔드 미설정 시 안전한 로그인 화면 |
| `iOS native build` | 건너뜀 | 수동 전체 CI와 iOS 출시 | macOS 26·Xcode 26 환경에서 iOS 앱과 위젯 확장 빌드 |
| `Node services` | 체크는 항상, 세부 테스트는 관련 변경만 | 전체 실행 | 변경 감지 실패 전달, 저장소 출시 계약, AI 서비스 테스트, 정책 웹 lint·빌드·렌더링 테스트 |
| `Edge functions` | 관련 변경 | 전체 실행과 Supabase 출시 | Node 단위 테스트 자동 검색, 런타임 환경 매니페스트 대조, Deno 진입점 타입 검사 |
| `Supabase database` | 건너뜀 | 수동 전체 CI와 Supabase 출시 | 빈 로컬 DB에 전체 마이그레이션 적용, pgTAP, DB lint |

CI 워크플로 또는 경로 분류 파일 자체가 바뀌면 자동 실행 대상인 경량 검증을
모두 실행한다. Android 에뮬레이터, macOS runner, Supabase 로컬 DB처럼 시간과
비용이 큰 검증은 `workflow_dispatch` 수동 전체 CI에서만 실행한다.
`services/ai-api/src/**`는 Edge Function이 직접 가져오는 공유 소스이므로 AI와
Edge 검증을 함께 실행한다.

iOS 네이티브 코드나 모바일 릴리스 계약 입력만 바뀌어도 이를 직접 읽는
Flutter 테스트는 자동 실행한다. Java 설정, Android 네이티브 테스트, 디버그
APK 빌드는 수동 전체 CI에서 실행한다. 개발 중에는 아래 로컬 스크립트로 같은
범위를 먼저 검증하고, 출시 워크플로가 해당 플랫폼의 고비용 검증을 다시
수행한다.

GitHub 저장소의 브랜치 보호 규칙에서는 기존 체크 이름을 `main` 병합 전
필수로 유지한다. 고비용 작업은 자동 실행에서 작업 수준 `if` 조건으로
건너뛰고 수동 전체 CI와 출시 과정에서 검증한다.
조건에 맞지 않는 작업은 GitHub의 작업 수준 `if` 조건으로 건너뛰므로 기존
필수 체크 이름은 유지된다. `Node services`가 변경 감지 실패까지 전달하므로
브랜치 보호에 새 체크를 추가하지 않아도 기존 실패 차단 경계가 유지된다.
워크플로 자체의 쓰기 권한이나 배포 비밀키는 추가하지 않는다.

Android·iOS·Supabase 운영 배포 워크플로는 실행 빈도가 낮고 서명·마이그레이션·
운영 환경을 다루므로, 선택적 CI 결과와 별개로 배포 직전에 전체 관련 검증을
다시 수행한다.

Supabase 운영 배포 설정과 실행 절차는
`docs/release/supabase-production-deployment.md`를 따른다.

## 로컬 검증

개발 중 피드백은 GitHub Actions 실행을 기다리지 않고 변경한 구성요소의 로컬
명령으로 먼저 확인한다. 커밋과 푸시 이후의 Actions는 로컬 검증을 대신하는
테스트 러너가 아니라 깨끗한 환경에서 수행하는 독립 확인 단계다. 수동 전체
CI는 출시 후보 확인이나 CI 경로 규칙 변경 검증에 사용한다.

Windows 모바일 전체 검증은 저장소 루트에서 다음 종료형 스크립트로 실행한다.
연결된 기기나 이미 실행 중인 에뮬레이터가 여러 대면 `-DeviceId`를 지정한다.

```powershell
.\scripts\verify_mobile_local.ps1
.\scripts\verify_mobile_local.ps1 -DeviceId <device-id>
```

스크립트는 의존성 복원, 포맷, 정적 분석, Flutter 테스트, Android 네이티브
테스트, 프로덕션 콜드 스타트 통합 테스트, 디버그 APK 빌드, Flutter cache
검증 순서로 실행하고 끝난다. `apps/mobile/.env`가 있으면 APK 빌드에만
`--dart-define-from-file=.env`로 사용한다. 콜드 스타트 테스트에는 의도적으로
릴리스 설정을 넣지 않아 설정이 없는 설치도 안전하게 로그인 화면까지
도달하는지 확인한다.

iOS 앱과 위젯 확장의 전체 로컬 검증은 macOS에서 저장소 루트의 스크립트로
수행한다. 서명 자격 증명이나 App Store Connect 비밀키는 필요하지 않다.

```bash
./scripts/verify_ios_local.sh
```

스크립트는 Flutter 3.41.9를 확인한 뒤 의존성 복원, 포맷, 정적 분석, Flutter
테스트, iOS 시뮬레이터 무서명 빌드를 실행한다. GitHub Actions에서는
`macos-26` runner를 사용해 제출 도구 체인과 같은
Xcode 26·iOS 26 SDK 세대에서 이 검증을 수행한다. 이 작업은 시뮬레이터용
무서명 빌드이므로 제출 가능한 IPA를 만들거나 App Store Connect에
업로드하지 않는다.

Node와 Edge 함수 검증은 종료형 명령으로 실행한다.

```powershell
node --test "tests/release/*.test.mjs"
node scripts/verify_tracked_secrets.mjs

cd services/ai-api
npm.cmd test

cd ..\..\apps\policy-web
npm.cmd ci
npm.cmd run lint
npm.cmd test

cd ..\..
node scripts/verify_supabase_runtime_environment.mjs
node scripts/test_supabase_functions.mjs
$entrypoints = Get-ChildItem supabase/functions -Directory |
  ForEach-Object { Join-Path $_.FullName 'index.ts' } |
  Where-Object { Test-Path -LiteralPath $_ }
deno check $entrypoints
```

운영 Edge Function 환경변수의 분류와 원격 대조 절차는
`docs/release/supabase-runtime-configuration.md`를 따른다.

데이터베이스 전체 로컬 검증에는 실행 중인 Docker 호환 런타임이 필요하다.
스크립트는 Supabase CLI `2.109.1`을 고정해서 사용하며, 로컬 Supabase가 꺼져
있을 때만 시작하고 자신이 시작한 경우에만 종료한다.

```powershell
.\scripts\verify_database_local.ps1
```

## 버전 갱신

워크플로에 적힌 액션 주석의 릴리스 태그를 공식 저장소에서 확인한 뒤,
태그가 가리키는 전체 SHA를 조회해 함께 갱신한다.

```powershell
git ls-remote https://github.com/actions/checkout.git refs/tags/v6.0.2
```

Flutter, Node, Deno, Supabase CLI 버전은 코드와 로컬 검증 버전을 함께
변경하고 네 필수 체크가 통과한 뒤 반영한다.
