# 모바일 서명 및 capability 준비

작성일: 2026-07-29

이 문서는 저장소에서 자동화할 수 없는 Android 업로드 키와 Apple Developer
계정 설정을 재현하기 위한 체크리스트다. 실제 키, 비밀번호, Team ID는 Git에
커밋하지 않는다.

## 1. Android 업로드 키

Google Play 신규 앱은 Android App Bundle로 제출하고 Play App Signing을
사용한다. 로컬 업로드 키는 다음 명령으로 생성할 수 있다.

```powershell
keytool -genkeypair -v `
  -keystore apps/mobile/android/upload-keystore.jks `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

`apps/mobile/android/key.properties.example`을
`apps/mobile/android/key.properties`로 복사한 뒤 실제 값을 입력한다.
`storeFile`은 `apps/mobile/android` 기준 경로다.

```properties
storeFile=upload-keystore.jks
storePassword=<UPLOAD_STORE_PASSWORD>
keyAlias=upload
keyPassword=<UPLOAD_KEY_PASSWORD>
```

`key.properties`, `*.jks`, `*.keystore`는 Git에서 제외되어 있다. 업로드 키는
암호화된 별도 보관소에 백업하고 접근 권한을 제한한다.

CI에서는 파일을 작업 공간에 복원한 다음 아래 환경변수를 사용한다.

- `DANJJAN_UPLOAD_STORE_FILE`
- `DANJJAN_UPLOAD_STORE_PASSWORD`
- `DANJJAN_UPLOAD_KEY_ALIAS`
- `DANJJAN_UPLOAD_KEY_PASSWORD`

네 값 중 하나라도 없거나 키 파일이 존재하지 않으면 `preReleaseBuild`가
실패한다. 디버그 키로 대신 서명하지 않는다.

릴리스 후보는 다음 명령으로 AAB를 만들고 Play Console 내부 테스트 트랙에
먼저 올린다.

```powershell
apps/mobile/flutterw.cmd build appbundle --release
```

### GitHub Actions 릴리스 후보

`.github/workflows/android-release.yml`은 자동 배포가 아니라 명시적으로
실행하는 릴리스 후보 생성 작업이다. GitHub의 `android-release`
Environment에 다음 secret을 등록한다.

- `DANJJAN_UPLOAD_KEYSTORE_BASE64`
- `DANJJAN_UPLOAD_STORE_PASSWORD`
- `DANJJAN_UPLOAD_KEY_ALIAS`
- `DANJJAN_UPLOAD_KEY_PASSWORD`
- `DANJJAN_SUPABASE_URL`
- `DANJJAN_SUPABASE_ANON_KEY`
- `DANJJAN_KAKAO_NATIVE_APP_KEY`

Supabase URL·anon key와 Kakao Native App Key는 최종 앱에 포함되는 클라이언트
설정이지만, 워크플로 로그에 노출되지 않도록 Environment secret으로
관리한다. service role key, Gemini API key와 같은 서버 비밀키는 모바일
빌드에 넣지 않는다.

공개 정책 웹을 배포한 뒤 같은 Environment의 variable에 다음 값을
등록한다.

- `DANJJAN_POLICY_BASE_URL`: 쿼리와 fragment가 없는 HTTPS 정책 웹 기본 주소

이 주소는 공개 정보이므로 secret이 아니라 Environment variable로
관리한다. 앱은 기본 주소 아래의 `/privacy`와 `/terms`를 설정 화면에서
외부 브라우저로 연다. 값이 없거나 안전한 HTTPS 주소가 아니면 릴리스 후보
작업이 실패한다.

PowerShell에서 업로드 키를 Base64로 바꿔 클립보드에 넣을 수 있다.

```powershell
$keystoreBase64 = [Convert]::ToBase64String(
  [IO.File]::ReadAllBytes(
    (Resolve-Path "apps/mobile/android/upload-keystore.jks")
  )
)
$keystoreBase64 | Set-Clipboard
```

GitHub CLI를 사용하는 경우 Environment secret을 대화형으로 등록한다.

```powershell
$keystoreBase64 | gh secret set DANJJAN_UPLOAD_KEYSTORE_BASE64 `
  --env android-release
gh secret set DANJJAN_UPLOAD_STORE_PASSWORD --env android-release
gh secret set DANJJAN_UPLOAD_KEY_ALIAS --env android-release
gh secret set DANJJAN_UPLOAD_KEY_PASSWORD --env android-release
gh secret set DANJJAN_SUPABASE_URL --env android-release
gh secret set DANJJAN_SUPABASE_ANON_KEY --env android-release
gh secret set DANJJAN_KAKAO_NATIVE_APP_KEY --env android-release
gh variable set DANJJAN_POLICY_BASE_URL --env android-release `
  --body "https://정책-웹-기본-주소"
```

Actions의 `Android release candidate`를 실행할 때 Play Console에서 아직
사용하지 않은 양의 `build_number`를 입력한다. 작업은 분석·테스트를 통과한
후 서명된 AAB를 만들고 다음 파일을 90일 동안 하나의 artifact로 보관한다.

- `danjjan-android-build-<BUILD_NUMBER>.aab`
- AAB의 SHA-256
- ProGuard/R8 mapping 파일과 SHA-256
- commit SHA, 앱 version, build number, 생성 시각

워크플로는 AAB 내부에 native debug symbol과 ProGuard mapping이 포함됐는지도
확인한다. Play Console 업로드는 개발자 계정과 테스트 트랙이 준비된 뒤
별도 승인 단계로 추가하며, 현재 워크플로에서는 수행하지 않는다.

참고:

- [Android 앱 서명](https://developer.android.com/studio/publish/app-signing)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)
- [GitHub Actions secrets](https://docs.github.com/en/actions/concepts/security/secrets)
- [GitHub Actions artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)

## 2. iOS Runner capability

Mac에서 `apps/mobile/ios/Runner.xcworkspace`를 열고 Runner target에 같은
Development Team을 지정한다. Apple Developer의
`com.vinscent.vinscent` App ID와 Xcode target 양쪽에 다음 capability가
필요하다.

- App Groups: `group.com.vinscent.vinscent`
- Push Notifications
- Sign in with Apple
- Background Modes
  - Audio, AirPlay, and Picture in Picture
  - Background fetch
  - Background processing
  - Remote notifications

Firebase Console의 iOS 앱 설정에는 APNs authentication key(`.p8`), Key ID,
Team ID를 등록한다.

Runner의 소스 entitlement에는 개발용 `aps-environment`가 들어간다.
App Store 아카이브의 최종 서명 entitlement는 배포 프로비저닝 프로파일에
따라 `production`이어야 한다.

참고:

- [Firebase Cloud Messaging Flutter 설정](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [APS environment entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment)
- [Sign in with Apple 구성](https://developer.apple.com/documentation/xcode/configuring-sign-in-with-apple)

## 3. iOS 위젯 capability

`VinscentWidgets` target과 `com.vinscent.vinscent.widgets` App ID에는 같은
Development Team과 App Group만 설정한다.

- App Groups: `group.com.vinscent.vinscent`

푸시 알림과 Sign in with Apple entitlement는 위젯에 추가하지 않는다. 위젯은
iOS 18 이상을 대상으로 하며, Runner와 동일한 App Group을 통해 표시 데이터와
녹음 임시 파일을 공유한다.

## 4. 아카이브 검증

공개 정책 웹과 앱 런타임 값을 포함한 릴리스 후보는 저장소 루트에서 다음
환경변수를 설정한 뒤 종료형 스크립트로 만든다.

```bash
export DANJJAN_SUPABASE_URL="https://프로젝트.supabase.co"
export DANJJAN_SUPABASE_ANON_KEY="<anon-key>"
export DANJJAN_KAKAO_NATIVE_APP_KEY="<native-app-key>"
export DANJJAN_POLICY_BASE_URL="https://정책-웹-기본-주소"
scripts/build_ios_release_candidate.sh 1
```

스크립트는 macOS와 양의 build number, Xcode 26 이상, iOS 26 SDK 이상,
필수 값, Supabase·정책 웹의 HTTPS를 검증한다. 이후 전체 분석·테스트와
`flutter build ipa --release`를 실행하고 다음 증빙을
`apps/mobile/build/release-evidence/ios-build-<BUILD_NUMBER>`에 만든다.

- IPA와 SHA-256
- dSYM을 포함한 `.xcarchive.zip`과 SHA-256
- commit SHA, 앱 version, build number, Xcode·iOS SDK version, 생성 시각

빌드 번호별 증빙 디렉터리가 이미 있으면 덮어쓰지 않고 실패한다. 스크립트는
App Store Connect에 업로드하지 않으므로 Organizer 또는 Transporter에서
검증 후 사람이 업로드한다.

Mac에서 Release 아카이브를 만든 뒤 Organizer에서 다음을 확인한다.

1. Runner와 위젯의 bundle identifier와 Development Team이 올바르다.
2. Runner의 서명 entitlement에 `aps-environment=production`,
   `com.apple.developer.applesignin`, App Group이 있다.
3. 위젯의 서명 entitlement에는 App Group만 있고 Runner 전용 entitlement는
   없다.
4. 실제 iPhone에서 Apple 로그인, 종료 상태 푸시 수신, 위젯 표시·녹음·재생을
   검증한다.
5. 개인정보 manifest와 App Privacy Report 검증은
   `docs/release/ios-privacy-declaration.md`를 따른다.

저장소에는 `DEVELOPMENT_TEAM`을 하드코딩하지 않는다. 팀 선택과 App ID
capability 활성화는 Apple 계정 권한이 있는 담당자가 수행한다.

참고:

- [Flutter iOS 릴리스](https://docs.flutter.dev/deployment/ios)
- [App Store Connect build 업로드](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [Apple SDK 최소 제출 요구사항](https://developer.apple.com/news/upcoming-requirements/)
