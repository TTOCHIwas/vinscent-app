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

참고:

- [Android 앱 서명](https://developer.android.com/studio/publish/app-signing)
- [Android App Bundle](https://developer.android.com/guide/app-bundle)

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
