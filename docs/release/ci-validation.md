# CI 검증 기준

## 목적

`.github/workflows/ci.yml`은 Pull Request와 `main` 브랜치 변경에서 출시 전
회귀를 검증한다. 이 워크플로는 원격 Supabase, Play Console, App Store
Connect에 배포하지 않으며 배포 비밀키를 사용하지 않는다.

`.github/workflows/supabase-production.yml`은 CI와 분리된 수동 운영 배포
워크플로다. 정확한 `main` commit과 project ref 확인, GitHub Environment
승인, 동일한 Database·Edge 검증을 모두 통과한 뒤에만 migration과
Edge Function을 배포한다.

`.github/workflows/store-assets.yml`은 출시 후보 화면을 캡처하고 저장소에
추가한 뒤 실행하는 수동 검증 워크플로다. 일반 PR과 출시 후보 빌드를
차단하지 않으며 실제 앱 버전과 빌드 번호를 입력받아 Play·App Store 문구
제한과 스토어 그래픽 자산 계약을 검증한다.

GitHub 문서의 권고에 따라 워크플로 권한은 `contents: read`로 제한하고,
외부 액션은 전체 커밋 SHA로 고정한다.

- [GitHub Actions 보안 사용 지침](https://docs.github.com/en/actions/reference/security/secure-use)
- [Flutter 통합 테스트](https://docs.flutter.dev/testing/integration-tests)
- [GitHub-hosted Android 하드웨어 가속](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub macOS 26 runner 이미지](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
- [Supabase 자동화된 데이터베이스 테스트](https://supabase.com/docs/guides/deployment/ci/testing)

## 필수 체크

| 체크 | 검증 범위 |
|---|---|
| `Flutter` | 의존성 복원, Dart 표준 포맷, 정적 분석, 전체 Flutter 테스트, Android 디버그 APK |
| `Android integration` | API 36 에뮬레이터에서 프로덕션 진입점 콜드 스타트, Firebase·홈 위젯 플러그인 등록, 백엔드 미설정 시 안전한 로그인 화면 |
| `iOS native build` | `main` 반영 또는 수동 실행 시 macOS 26·Xcode 26 환경에서 iOS 앱과 위젯 확장 시뮬레이터 빌드 |
| `Node services` | 저장소 출시·비밀값 계약, AI 서비스 테스트, 정책 웹 lint·빌드·렌더링 테스트 |
| `Edge functions` | Node 단위 테스트 자동 검색, 런타임 환경 매니페스트 대조, Deno 진입점 타입 검사 |
| `Supabase database` | 빈 로컬 DB에 전체 마이그레이션 적용, pgTAP, DB lint |

GitHub 저장소의 브랜치 보호 규칙에서 Linux에서 실행되는 다섯 체크를
`main` 병합 전 필수로 설정한다. macOS 비용을 제한하기 위해 iOS 빌드는
Pull Request에서는 건너뛰고 `main` 반영 직후와 수동 실행에서 검증한다.
워크플로 자체의 쓰기 권한이나 배포 비밀키는 추가하지 않는다.

Supabase 운영 배포 설정과 실행 절차는
`docs/release/supabase-production-deployment.md`를 따른다.

## 로컬 검증

Windows에서는 저장소에 포함된 Flutter 래퍼를 사용한다.

```powershell
cd apps/mobile
..\..\.toolchains\flutter\bin\dart.bat format --output=none --set-exit-if-changed lib test integration_test
.\flutterw.cmd pub get
.\flutterw.cmd analyze --no-pub
.\flutterw.cmd test --no-pub
.\flutterw.cmd build apk --debug --no-pub
```

Android 통합 테스트는 실제 기기 또는 에뮬레이터가 연결된 환경에서만
실행한다. 이 테스트는 릴리스 비밀값을 주입하지 않은 프로덕션 진입점이
네이티브 플러그인을 등록하고 안전하게 로그인 화면까지 도달하는지
확인한다.

```powershell
cd apps/mobile
.\flutterw.cmd test integration_test/app_startup_test.dart --no-pub
```

iOS 앱과 위젯 확장의 컴파일 검증은 macOS에서 다음 명령으로 수행한다.
서명 자격 증명이나 App Store Connect 비밀키는 필요하지 않다.

```bash
cd apps/mobile
flutter pub get
flutter build ios --simulator --debug --no-codesign --no-pub
```

GitHub Actions에서는 `macos-26` runner를 사용해 제출 도구 체인과 같은
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

데이터베이스 검증에는 Docker 호환 런타임과 Supabase CLI `2.109.1`이
필요하다.

```powershell
supabase db start
supabase test db
supabase db lint --local --level error
supabase stop --no-backup
```

## 버전 갱신

워크플로에 적힌 액션 주석의 릴리스 태그를 공식 저장소에서 확인한 뒤,
태그가 가리키는 전체 SHA를 조회해 함께 갱신한다.

```powershell
git ls-remote https://github.com/actions/checkout.git refs/tags/v6.0.2
```

Flutter, Node, Deno, Supabase CLI 버전은 코드와 로컬 검증 버전을 함께
변경하고 네 필수 체크가 통과한 뒤 반영한다.
