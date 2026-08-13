# iOS Mac 작업 인계

작성일: 2026-08-13

## 목적

Windows에서 준비할 수 없는 작업만 Mac에 남긴다. Mac에서는 CocoaPods 잠금
생성, Apple Distribution 인증서와 프로비저닝 프로파일 준비, 실제 iPhone
검증만 수행한다. 서명된 IPA 생성과 TestFlight 업로드는 이후 GitHub Actions의
`iOS release candidate`가 담당한다.

모든 명령은 종료형이다. 개발 서버나 감시 프로세스를 실행하지 않는다.

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

## Mac에 가기 전 웹 설정

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
지정한다.

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

## Mac에서 한 번만 하는 작업

### 1. 도구와 소스 확인

1. Xcode 26 이상을 설치하고 한 번 실행해 license와 추가 component 설치를
   마친다.
2. Flutter `3.41.9`와 CocoaPods를 설치한다.
3. 저장소 `main`을 최신 상태로 받고 GitHub CLI에 로그인한다.

```bash
cd <vinscent-repository>
git switch main
git pull --ff-only
flutter --version
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
pod --version
```

### 2. CocoaPods 잠금 최초 생성

현재 저장소에 `apps/mobile/ios/Podfile.lock`과 CocoaPods workspace 참조가
없다면 Mac에서 한 번 생성해야 한다.

```bash
cd <vinscent-repository>/apps/mobile
flutter pub get
cd ios
pod install
cd ../../..
git status --short
```

`apps/mobile/ios/Podfile.lock`과
`apps/mobile/ios/Runner.xcworkspace/contents.xcworkspacedata`를 검토해
커밋하고 `main`에 반영한다. 다른 Xcode 설정 변경은 함께 커밋하지 않는다.

```bash
git add apps/mobile/ios/Podfile.lock \
  apps/mobile/ios/Runner.xcworkspace/contents.xcworkspacedata
git commit -m 'build: iOS CocoaPods 잠금 추가'
git push origin main
```

최신 commit에서 종료형 사전 점검을 실행한다.

```bash
scripts/check_ios_release_mac.sh "$(git rev-parse HEAD)"
```

### 3. Apple Distribution 인증서

1. Keychain Access의 Certificate Assistant에서 CSR을 만든다.
2. Apple Developer의 Certificates에서 Apple Distribution 인증서를 만든다.
3. 내려받은 인증서를 Mac Keychain에 설치한다.
4. 인증서와 연결된 private key를 함께 선택해 비밀번호가 있는 `.p12`로
   내보낸다.

인증서만 내보내거나 `.cer`만 등록하면 CI에서 서명할 수 없다. `.p12`에는
private key가 포함되어야 한다.

### 4. App Store Connect 프로비저닝 프로파일

Apple Developer에서 App Store Connect 배포 profile 두 개를 별도로 만든다.

- Runner: `com.vinscent.vinscent`
- Widget: `com.vinscent.vinscent.widgets`

두 profile 모두 같은 Apple Distribution 인증서를 선택한다. Runner profile은
App Group, production push, Sign in with Apple을 포함해야 한다. Widget profile은
App Group만 포함해야 한다.

### 5. 서명 자산을 GitHub에 등록

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

### 6. 실제 iPhone 검증

`apps/mobile/ios/Runner.xcworkspace`를 Xcode로 열고 Runner와
VinscentWidgets에 같은 Development Team을 선택한다. 다음을 실제 iPhone에서
확인한다.

1. Apple 최초 로그인과 재로그인
2. Apple 계정의 재인증을 포함한 계정 삭제
3. foreground, background, 종료 상태 푸시
4. 캐릭터·카드 위젯 표시와 갱신
5. 위젯 녹음 시작·종료, 앱·위젯 재생
6. 카메라, 마이크, 사진, 위치, 알림 권한 흐름
7. 큰 글자와 홈 인디케이터 환경의 하단 UI

Xcode가 Team ID를 project file에 기록했다면 실기기 검증 뒤 해당 로컬 변경을
출시 commit에 섞지 않는다. GitHub 릴리스는 Environment의 Team ID와 수동
profile을 주입한다.

## TestFlight 배포

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
commit을 `publish_testflight=true`로 실행한다. App Store Connect에 이미 올라간
build number는 재사용하지 않는다.

```bash
gh workflow run ios-release.yml --ref main \
  -f commit_sha_confirmation="$release_sha" \
  -f build_number='<새로운-고유한-양의-정수>' \
  -f publish_testflight=true
```

업로드 성공 직후 build가 바로 보이지 않을 수 있다. Apple 처리가 끝나면
App Store Connect의 TestFlight에서 내부 tester에게 배포하고 설치한다.

## 완료 기준

- Mac 사전 점검 통과
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
