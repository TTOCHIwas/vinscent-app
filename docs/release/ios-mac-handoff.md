# iOS Mac 작업 인계

작성일: 2026-09-06

## 목적

Windows에서 준비할 수 없는 작업만 Mac에 남긴다. 현재 CocoaPods 잠금, Apple
서명 자산을 주입하는 GitHub Actions, TestFlight 업로드 경로는 이미 준비되어
있다. 이번 Mac 작업은 마지막 성공한 TestFlight 빌드 이후 변경분을 iOS에서
검증하고, 발견한 플랫폼 문제를 고친 뒤 다음 릴리스 후보를 준비하는 데
집중한다.

서명된 IPA 생성과 TestFlight 업로드는 GitHub Actions의
`iOS release candidate`가 담당한다. Mac 로컬에서는 소스 검증, 시뮬레이터
빌드, Xcode 진단과 실제 iPhone 검증을 수행한다.

모든 명령은 종료형이다. 개발 서버나 감시 프로세스를 실행하지 않는다.

Mac의 Codex에 작업을 이어 맡길 때는
[`ios-mac-codex-prompt.md`](ios-mac-codex-prompt.md)를 첫 메시지로 사용한다.

## 현재 기준점

| 항목 | 확인된 상태 |
|---|---|
| 마지막 TestFlight 업로드 성공 | GitHub Actions run `31784245770` |
| 마지막 업로드 commit | `8c96489fa1f3684786a486f44fa08d6ce325fe71` |
| 마지막 업로드 build number | `2026081408` |
| CocoaPods 잠금 | `apps/mobile/ios/Podfile.lock` 추적 중 |
| CocoaPods workspace 참조 | `apps/mobile/ios/Runner.xcworkspace/contents.xcworkspacedata` 추적 중 |
| iOS CD 설정 | `ios-release` 필수 secret 8개와 variable 4개 등록 확인 |

마지막 성공 실행에서는 서명된 IPA 생성, 업로드 검증, TestFlight 업로드까지
모두 통과했다. 따라서 오류 증거가 없으면 인증서, 프로비저닝 프로파일,
App Store Connect API key를 새로 만들지 않는다.

이후 변경량이 크므로 마지막 TestFlight 앱이 현재 `main`을 대표한다고 보면
안 된다. Mac에서 다음 명령으로 실제 검증 범위를 먼저 확인한다.

```bash
git log --oneline \
  8c96489fa1f3684786a486f44fa08d6ce325fe71..HEAD
```

Windows에서는 전체 Flutter 테스트 1,093개와 정적 분석을 통과했다. 운영
Supabase 설정을 요구하는 부트스트랩 테스트 1개는 조건 미충족으로 건너뛰었다.
Swift 컴파일, CocoaPods 통합, iOS 시뮬레이터와 실제 iPhone 동작은 Windows에서
검증할 수 없으므로 Mac 완료 항목으로 남는다.

## 이번 Mac 작업 순서

### 1. 깨끗한 최신 `main` 준비

```bash
cd <vinscent-repository>
git switch main
git pull --ff-only origin main
git status --short
git rev-parse HEAD
```

`git status --short`에 사용자가 만든 변경이 있으면 삭제하거나 덮어쓰지 말고
먼저 내용을 확인한다. 릴리스 사전 점검은 추적·비추적 변경이 없는 소스에서만
통과한다.

### 2. 로컬 실행 설정 준비

`apps/mobile/.env`와
`apps/mobile/ios/Flutter/Kakao.generated.xcconfig`는 의도적으로 Git에서
제외된다. GitHub secret 값은 CLI로 다시 읽을 수 없으므로 안전한 별도 경로로
Mac에 전달해 준비한다.

```bash
cd <vinscent-repository>/apps/mobile
cp -n .env.example .env
```

`.env`에는 다음 네 값을 채운다. 값을 터미널 출력, Git, 문서나 Codex
프롬프트에 남기지 않는다.

```dotenv
SUPABASE_URL=<운영 URL>
SUPABASE_ANON_KEY=<운영 anon key>
KAKAO_NATIVE_APP_KEY=<카카오 Native App Key>
POLICY_BASE_URL=<운영 정책 웹 HTTPS 주소>
```

카카오 콜백 scheme이 네이티브 빌드에도 들어가도록 비추적 xcconfig를 만든다.

```bash
kakao_key="$(sed -n 's/^KAKAO_NATIVE_APP_KEY=//p' .env)"
test -n "$kakao_key"
printf 'KAKAO_NATIVE_APP_KEY=%s\n' "$kakao_key" \
  > ios/Flutter/Kakao.generated.xcconfig
unset kakao_key
```

### 3. 의존성과 전체 로컬 검증

```bash
cd <vinscent-repository>/apps/mobile
flutter --version
flutter pub get
cd ios
pod install --deployment
cd ../../..
./scripts/verify_ios_local.sh
```

`verify_ios_local.sh`는 Flutter `3.41.9`, 포맷, 정적 분석, 전체 Flutter 테스트와
iOS 시뮬레이터 무서명 디버그 빌드를 검증한다. 실패하면 뒤 단계를 진행하지
않고 caller에서 실제 실패 method까지 추적해 고친다.

### 4. Xcode와 시뮬레이터 검증

```bash
open apps/mobile/ios/Runner.xcworkspace
```

`Runner.xcodeproj`가 아니라 `Runner.xcworkspace`를 연다. 작은 iPhone과 큰
iPhone 시뮬레이터에서 기본 글자, 큰 글자, 홈 인디케이터 Safe Area를 확인한다.
현재 iPhone은 portrait와 두 landscape 방향을 모두 선언하므로 landscape를
지원할지 별도로 결정하기 전까지는 세 방향에서 깨짐이 없는지도 확인한다.

런타임 설정이 필요한 앱 실행은 다음 형식을 사용한다.

```bash
cd <vinscent-repository>/apps/mobile
flutter devices
flutter run -d <simulator-or-device-id> \
  --dart-define-from-file=.env
```

### 5. 최근 변경분 iOS 회귀 검증

#### 캘린더 표시

1. 한국 지역 설정에서 일요일과 공휴일이 구분되고, 공휴일 이름이 선택 날짜
   상세에 올바르게 표시되는지 확인한다.
2. 한국 이외 지역에서는 공휴일 표시가 기본으로 꺼지는지 확인한다.
3. 날짜 선택 시 해당 날짜의 주간 상세 상태로 진입하는지 확인한다.
4. 전체 월간, 기본 월간, 주간, 날짜 상세 전환을 모두 확인한다.
5. 이전·다음 달 스와이프 중 일정과 카드가 함께 자연스럽게 이동하는지
   확인한다.
6. 인접 월의 카드·일정과 사진 미리보기가 전환 전에 준비되어 빈 화면이나
   번쩍임이 없고, 메모리 사용이나 네트워크 요청이 비정상적으로 늘지 않는지
   확인한다.
7. 오늘 날짜가 브랜드색 채움과 흰 글자로 보이고, 오늘이 아닌 선택 날짜는
   검정 채움으로 유지되는지 확인한다.

#### UI 회귀

1. 홈과 캘린더 상세의 캐릭터 발화가 가로 배치와 무배경 표현을 유지하는지
   확인한다.
2. 시스템 글자 크기가 작거나 커도 캐릭터, 텍스트, AI 표시가 분리되어 보이지
   않는지 확인한다.
3. AI 물어보기 화면의 입력창, 질문, 답변, 기록 및 저장 동작을 확인한다.
4. 기존 녹음 슬롯을 드래그하는 순간 회색 오버레이가 남지 않는지 확인한다.
5. 새 녹음, 녹음 슬롯, 상위 녹음 버튼의 인디케이터가 같은 읽음 상태를
   공유하는지 확인한다.
6. 올바른 `.env`가 준비된 상태에서 앱을 처음 실행해도 Supabase 초기화 오류가
   발생하지 않는지 확인한다.
7. 선제 추천 문구와 AI 한마디가 홈에서 정상적으로 나타나고 닫히는지
   확인한다.
8. 그림·텍스트 팔레트, 스포이드, 가로 굵기 조절기, 하단 도구 배치가 Safe
   Area와 큰 글자에서 겹치지 않는지 확인한다.
9. 공통 확인창의 세로 행동 버튼과 단어 단위 줄바꿈이 작은 화면과 큰 글자에서
   잘리지 않는지 확인한다.

### 6. 실제 iPhone 전용 검증

다음 항목은 시뮬레이터 성공만으로 완료 처리하지 않는다.

1. Apple 최초 로그인, 재로그인, 취소와 실패 메시지
2. Apple 재인증을 포함한 앱 내 계정 삭제
3. 카카오톡 로그인과 카카오계정 fallback, 앱 복귀 callback
4. 알림 권한과 foreground, background, 종료 상태 푸시 및 알림 탭 이동
5. 기기 캘린더 권한 거부·허용, 캘린더 선택, 일정 생성·수정·삭제, 메모와
   매년 반복, 동기화 중단과 미러 일정 삭제
6. 캐릭터·카드 위젯 표시와 갱신
7. iOS 18 이상에서 위젯 녹음 시작·종료·업로드·재생과 권한 fallback
8. 카메라, 사진 추가·저장, 마이크, 위치 권한 흐름

#### iPhone 기기 캘린더 동기화

기기 캘린더 동기화는 Android, iOS EventKit bridge와 공통 Flutter coordinator에
이미 구현되어 있다. 새로 구현하지 않고 현재 호출 흐름과 실제 동작을
검증한다.

1. 동기화에 동의하지 않아도 앱 내부 캘린더가 기존처럼 작동하는지 확인한다.
2. 권한 허용, 거부, 설정 앱에서 재허용하는 흐름을 확인한다.
3. 쓰기 가능한 iCloud 또는 로컬 캘린더 선택을 확인한다.
4. 동기화를 처음 켰을 때 기존 앱 일정이 중복 없이 반영되는지 확인한다.
5. 앱 일정의 생성, 제목 수정, 날짜 수정, 메모 수정이 기기 캘린더에
   반영되는지 확인한다.
6. 날짜를 수정해도 새 일정이 중복 생성되지 않고 기존 일정이 이동하는지
   확인한다.
7. 매년 반복 일정이 다음 연도에도 나타나는지 확인한다.
8. 앱에서 일정을 삭제하면 대응하는 기기 일정만 삭제되는지 확인한다.
9. 동기화만 중단하면 기존 기기 일정이 유지되는지 확인한다.
10. `미러 일정도 삭제`를 선택하면 단짠이 생성한 일정만 삭제되는지 확인한다.
11. 기기 캘린더에서 수정한 내용은 앱으로 역수입되지 않는 단방향
    동기화인지 확인한다.
12. 실패 후 앱을 다시 열거나 동기화를 재시도했을 때 대기열이 정상
    처리되는지 확인한다.

EventKit 검증은 반드시 실제 iPhone에서 수행하고, 실기기에서 확인하지 못한
항목은 통과로 기록하지 않는다. 실패가 확인되면 caller에서 Flutter
coordinator, MethodChannel, Swift EventKit method 순서로 관련 파일과 호출자를
모두 수집해 추적한다. 기기 캘린더의 Dart coordinator 테스트는 존재하지만,
현재 `apps/mobile/ios/RunnerTests/RunnerTests.swift`는 예제 상태다. 문자열
검사나 임시 우회를 추가하지 말고 재현 가능한 XCTest 또는 테스트 가능한
네이티브 경계를 먼저 추가해 RED를 확인한 뒤 수정한다. Android와 공통 Flutter
동작은 변경하지 않는다.

### 7. 수정·보고·릴리스 사전 점검

Mac에서 발견한 문제는 한 의도당 한 커밋으로 나누고 관련 테스트를 먼저
실패시킨 뒤 구현한다. 사용자의 별도 승인 전에는 push와 TestFlight CD를
실행하지 않는다.

모든 수정이 커밋되고 작업 트리가 깨끗해지면 다음을 실행한다.

```bash
cd <vinscent-repository>
./scripts/check_ios_release_mac.sh "$(git rev-parse HEAD)"
```

최종 보고에는 HEAD SHA, 사용한 Xcode·SDK·Flutter·CocoaPods 버전, 자동 테스트
결과, 시뮬레이터별 결과, 실제 iPhone별 결과와 기기 모델·iOS 버전, 추가한
테스트와 커밋, 남은 문제와 출시 차단 여부, 릴리스 사전 점검 결과를 포함한다.
위의 각 세부 검증 항목은 `통과`, `실패`, `미검증` 중 하나로 구분한다. 자동
테스트만 통과했거나 실기기에서 한 번 동작한 것만으로 서로의 검증을 대신하지
않는다.

## 고정 식별자

| 대상 | 값 |
|---|---|
| Runner App ID | `com.vinscent.vinscent` |
| Widget App ID | `com.vinscent.vinscent.widgets` |
| App Group | `group.com.vinscent.vinscent` |
| Apple 로그인·계정 삭제 client ID | `com.vinscent.vinscent` |
| Firebase iOS bundle ID | `com.vinscent.vinscent` |
| Flutter | `3.41.9` |
| 최소 빌드 도구 | Xcode 26, iOS 26 SDK |

## 웹 설정을 다시 구성해야 할 때만 참고

아래 Apple Developer, Supabase, Firebase, App Store Connect 설정은 현재 출시
경로에 이미 구성되어 있다. 실제 로그인·푸시·서명 오류가 재현되거나 키가
만료·폐기된 경우에만 해당 서비스의 현재 상태와 대조한다. 정상 동작하는 키나
App ID 설정을 작업 시작 단계에서 다시 만들지 않는다.

### Apple Developer

1. Runner App ID에 App Groups, Push Notifications, Sign in with Apple을
   활성화한다.
2. Widget App ID에는 App Groups만 활성화한다. Push Notifications와 Sign in
   with Apple은 추가하지 않는다.
3. 두 App ID에 같은 App Group을 연결한다.
4. Sign in with Apple 전용 Key를 만들고 `.p8`, Key ID, Team ID를 안전하게
   보관한다.
5. Firebase 전용 APNs authentication key를 만들고 `.p8`, Key ID, Team ID를
   보관한다.

Sign in with Apple key와 APNs key는 목적과 폐기 주기가 다르므로 별도로 만든다.
App Store Connect API key도 별도 키다. 세 파일을 서로 바꿔 넣지 않는다.

### Supabase Dashboard

Auth의 Apple provider를 활성화하고 허용 Client ID 목록에
`com.vinscent.vinscent`를 넣는다. 현재 앱은 네이티브 Apple 로그인만 사용한다.
향후 웹 OAuth를 추가하면 Services ID를 첫 항목에 두고 Runner App ID도 목록에
유지한다.

`delete-account`가 Apple 권한을 철회할 수 있도록 다음 Edge Function secret을
등록한다.

| secret | 값 |
|---|---|
| `APPLE_SIGN_IN_CLIENT_ID` | `com.vinscent.vinscent` |
| `APPLE_SIGN_IN_TEAM_ID` | Apple Developer의 10자리 Team ID |
| `APPLE_SIGN_IN_KEY_ID` | Sign in with Apple key의 Key ID |
| `APPLE_SIGN_IN_PRIVATE_KEY` | Sign in with Apple `.p8` 전체 PEM 내용 |

`APPLE_SIGN_IN_CLIENT_ID`는 App Store Connect API key ID나 Services ID가
아니다. 앱이 Apple에서 직접 받은 네이티브 authorization code를 교환하므로
Runner App ID를 사용한다. 등록 후 실제 iPhone에서 Apple 재인증을 포함한 계정
삭제까지 검증한다.

### Firebase Console

Firebase 프로젝트의 iOS 앱 `com.vinscent.vinscent`에 APNs authentication
key, Key ID, Team ID를 등록한다. 저장소의
`apps/mobile/ios/Runner/GoogleService-Info.plist`도 같은 bundle ID를 사용한다.

### App Store Connect

1. `com.vinscent.vinscent`로 iOS app record를 만든다.
2. Users and Access > Integrations에서 TestFlight 업로드 전용 Team API key를
   만들고 Developer 역할을 부여한다.
3. `.p8`은 한 번만 내려받을 수 있으므로 즉시 암호화 백업한다.
4. Key ID와 Issuer ID를 함께 기록한다.

## GitHub `ios-release` Environment

Environment의 deployment branch를 `main`으로 제한하고 필요하면 승인자를
지정한다. 아래 secret 8개와 variable 4개는 2026-09-06 기준 모두 등록되어
있다. GitHub는 secret 값을 다시 보여주지 않으므로 이름과 등록 여부만
확인하고, 오류 증거 없이 값을 교체하지 않는다.

### Secrets

| 이름 | 준비 위치 |
|---|---|
| `DANJJAN_SUPABASE_URL` | 기존 운영 앱 설정 |
| `DANJJAN_SUPABASE_ANON_KEY` | 기존 운영 앱 설정 |
| `DANJJAN_KAKAO_NATIVE_APP_KEY` | 기존 운영 앱 설정 |
| `DANJJAN_ASC_API_PRIVATE_KEY_BASE64` | App Store Connect API `.p8`의 Base64 |
| `DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Mac에서 내보낸 `.p12`의 Base64 |
| `DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | `.p12` 내보내기 비밀번호 |
| `DANJJAN_IOS_RUNNER_PROFILE_BASE64` | Runner App Store Connect profile의 Base64 |
| `DANJJAN_IOS_WIDGET_PROFILE_BASE64` | Widget App Store Connect profile의 Base64 |

### Variables

| 이름 | 값 |
|---|---|
| `DANJJAN_POLICY_BASE_URL` | 쿼리·fragment 없는 운영 정책 웹 HTTPS 주소 |
| `DANJJAN_APPLE_TEAM_ID` | Apple Developer의 10자리 Team ID |
| `DANJJAN_ASC_API_KEY_ID` | App Store Connect API Key ID |
| `DANJJAN_ASC_API_ISSUER_ID` | App Store Connect API Issuer ID UUID |

App Store Connect API key를 Mac에서 Base64로 등록하는 예시는 다음과 같다.

```bash
openssl base64 -A -in AuthKey_<KEY_ID>.p8 |
  gh secret set DANJJAN_ASC_API_PRIVATE_KEY_BASE64 --env ios-release
gh variable set DANJJAN_ASC_API_KEY_ID --env ios-release --body '<KEY_ID>'
gh variable set DANJJAN_ASC_API_ISSUER_ID --env ios-release --body '<ISSUER_ID>'
gh variable set DANJJAN_APPLE_TEAM_ID --env ios-release --body '<TEAM_ID>'
```

## 서명 자산을 다시 발급해야 할 때만 참고

마지막 TestFlight 업로드에서 현재 `ios-release` 서명 경로가 성공했다. 아래
절차는 인증서·프로비저닝 프로파일의 만료, 폐기 또는 entitlement 불일치가
확인된 경우에만 수행한다.

### Apple Distribution 인증서

1. Keychain Access의 Certificate Assistant에서 CSR을 만든다.
2. Apple Developer의 Certificates에서 Apple Distribution 인증서를 만든다.
3. 내려받은 인증서를 Mac Keychain에 설치한다.
4. 인증서와 연결된 private key를 함께 선택해 비밀번호가 있는 `.p12`로
   내보낸다.

인증서만 내보내거나 `.cer`만 등록하면 CI에서 서명할 수 없다. `.p12`에는
private key가 포함되어야 한다.

### App Store Connect 프로비저닝 프로파일

Apple Developer에서 App Store Connect 배포 profile 두 개를 별도로 만든다.

- Runner: `com.vinscent.vinscent`
- Widget: `com.vinscent.vinscent.widgets`

두 profile 모두 같은 Apple Distribution 인증서를 선택한다. Runner profile은
App Group, production push, Sign in with Apple을 포함해야 한다. Widget profile은
App Group만 포함해야 한다.

### 서명 자산을 GitHub에 등록

```bash
openssl base64 -A -in <distribution-certificate.p12> |
  gh secret set DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_BASE64 --env ios-release
gh secret set DANJJAN_IOS_DISTRIBUTION_CERTIFICATE_PASSWORD --env ios-release
openssl base64 -A -in <runner.mobileprovision> |
  gh secret set DANJJAN_IOS_RUNNER_PROFILE_BASE64 --env ios-release
openssl base64 -A -in <widget.mobileprovision> |
  gh secret set DANJJAN_IOS_WIDGET_PROFILE_BASE64 --env ios-release
```

명령이 성공하면 원본 `.p12`, `.mobileprovision`, `.p8`을 작업 폴더에서 지우고
암호화 백업 위치에만 보관한다. 이 확장자는 Git에서 차단되어 있다.

## TestFlight 배포

Mac 검증 결과를 보고한 뒤 사용자가 별도로 승인한 경우에만 실행한다. 마지막
성공 build number `2026081408`과 App Store Connect에 이미 등록된 다른 build
number는 재사용하지 않는다.

먼저 업로드 없이 서명·검증만 수행한다.

```bash
cd <vinscent-repository>
release_sha="$(git rev-parse HEAD)"
gh workflow run ios-release.yml --ref main \
  -f commit_sha_confirmation="$release_sha" \
  -f build_number='<고유한-양의-정수>' \
  -f publish_testflight=false
```

Actions artifact의 IPA, archive, SHA-256, entitlement 보고서를 확인한 다음 같은
commit을 `publish_testflight=true`로 실행한다.

```bash
gh workflow run ios-release.yml --ref main \
  -f commit_sha_confirmation="$release_sha" \
  -f build_number='<새로운-고유한-양의-정수>' \
  -f publish_testflight=true
```

업로드 성공 직후 build가 바로 보이지 않을 수 있다. Apple 처리가 끝나면
App Store Connect의 TestFlight에서 내부 tester에게 배포하고 설치한다.

## 완료 기준

Mac 검증 완료:

- 최신 `main`의 전체 Flutter·iOS 시뮬레이터 빌드 검증 통과
- 작은·큰 iPhone 시뮬레이터의 최근 UI 변경 회귀 검증 통과
- 실제 iPhone의 로그인·푸시·기기 캘린더·위젯 smoke test 통과
- 발견한 수정과 테스트가 의도별 commit으로 정리됨
- Mac 사전 점검 통과

TestFlight 릴리스 완료:

- CocoaPods 잠금과 workspace 참조가 `main`에 고정됨
- GitHub `ios-release` secret·variable 등록 완료
- `publish_testflight=false` 릴리스 후보 검증 통과
- `publish_testflight=true` 업로드 통과
- 실제 iPhone Apple 로그인·계정 삭제·푸시·위젯 smoke test 통과

## 공식 근거

- [Supabase Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Apple App Store provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile)
- [Apple App Store Connect API keys](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)
- [Apple build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [GitHub Xcode signing](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [Firebase Cloud Messaging Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
