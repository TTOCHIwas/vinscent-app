# 개발 환경 셋업

작성일: 2026-05-06

## 1. 현재 결정된 방향

모바일 앱 기준 스택은 Flutter다.

현재 `apps/mobile`은 Flutter 프로젝트로 생성되어 있다. 이전 후보였던 Expo 스캐폴딩은 제거했다.

로컬 Flutter SDK는 프로젝트 내부 `.toolchains/flutter`에 설치했다. 이 폴더는 Git에 커밋하지 않는다.

Flutter 명령은 PowerShell에서 직접 실행할 때 lock/snapshot 문제가 발생할 수 있어, Windows `cmd` 래퍼를 사용한다.

```bash
scripts\flutter.cmd --version
```

확인된 버전:

- Flutter 3.41.9
- Dart 3.11.5

모바일 의존성을 추가하거나 버전을 올릴 때는 위 기준선 안에서 해석 가능한지 먼저 확인한다.

- `apps/mobile/pubspec.yaml`의 `environment.sdk`를 먼저 본다.
- 새 패키지의 Dart/Flutter 최소 요구 버전이 기준선을 넘으면 바로 추가하지 않는다.
- `apps/mobile`에서 아래 순서로 검증한 뒤에만 변경을 커밋한다.

```bash
cd apps/mobile
..\..\scripts\flutter.cmd pub get
..\..\scripts\flutter.cmd analyze
```

## 2. 사용자가 직접 해야 하는 일

### 2.1 Flutter SDK

현재 PC에는 프로젝트 로컬 Flutter SDK가 설치되어 있다.

새 PC에서 다시 셋업한다면 Windows에 Flutter SDK를 설치하거나, 동일하게 `.toolchains/flutter`에 Flutter SDK를 내려받는다.

설치 후 확인:

```bash
scripts\flutter.cmd --version
scripts\flutter.cmd doctor -v
```

### 2.2 Android 개발 환경

Windows에서 실제 개발 루프를 만들려면 Android 환경이 필요하다.

- Android Studio 설치
- Android SDK 설치
- Android Emulator 생성 또는 Android 실기기 준비
- 실기기 사용 시 USB debugging 활성화

현재 `flutter doctor` 기준 Android SDK가 설치되어 있지 않다. Android Studio 설치 후 SDK 설정이 필요하다.

### 2.3 iOS 테스트 환경

Windows에서는 iOS Simulator를 사용할 수 없다.

Flutter로 iOS 앱을 빌드하거나 iOS 실기기에 직접 실행하려면 macOS와 Xcode가 필요하다.

iOS 검증 선택지:

- iPhone 실기기 확보
- 원격 Mac 사용
- 중고 Mac mini 또는 MacBook 확보
- 출시 전 iOS QA 외주 또는 테스터 활용

iPhone만 있으면 최종 UI/사용성 확인에는 도움이 되지만, Flutter iOS 개발 루프를 완전히 대체하지는 못한다.

### 2.4 Supabase 프로젝트 생성

Supabase에서 새 프로젝트를 만든 뒤 다음 값을 앱 환경 변수로 연결해야 한다.

- Supabase project URL
- Supabase anon key

현재 앱은 `--dart-define` 값을 우선 사용한다.

```bash
scripts\flutter.cmd run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

예시 값은 `apps/mobile/.env.example`에 둔다. 실제 값은 Git에 커밋하지 않는다.

### 2.5 계정 준비

초기 개발:

- Supabase 계정

Android 배포:

- Google Play Developer 계정

iOS 배포:

- Apple Developer Program 계정
- macOS/Xcode 환경 또는 macOS CI

추후 필요:

- Kakao Developers 계정
- Google Cloud 계정
- Firebase 프로젝트
- OpenAI API 계정

## 3. Flutter 프로젝트 명령어

프로젝트 생성은 완료되어 있다.

재생성이 필요할 때 사용할 수 있는 기본 명령어:

```bash
scripts\flutter.cmd create --org com.vinscent --project-name vinscent apps/mobile
```

현재 설치된 초기 패키지:

- supabase_flutter
- flutter_riverpod
- go_router
- flutter_secure_storage
- flutter_dotenv

추후 기능이 들어가는 시점에 추가할 후보:

```bash
scripts\flutter.cmd pub add firebase_messaging flutter_local_notifications
scripts\flutter.cmd pub add lottie rive
scripts\flutter.cmd pub add freezed_annotation json_annotation
scripts\flutter.cmd pub add --dev build_runner freezed json_serializable
```

## 4. 현재 검증 상태

통과:

```bash
scripts\flutter.cmd --version
scripts\flutter.cmd doctor -v
scripts\flutter.cmd pub get
scripts\flutter.cmd analyze
```

`analyze`는 `apps/mobile`에서 통과했다.

미완료:

- `flutter test`는 현재 Windows 환경에서 첫 실행 중 타임아웃이 발생했다.
- Android SDK가 없어 Android Emulator 실행은 아직 불가하다.
- iOS 검증은 Mac/Xcode 또는 원격 Mac 환경이 필요하다.

## 5. 당장 하지 않아도 되는 일

- 관리자 웹 구현
- 결제 연동
- AI 서버 배포
- iOS App Store 배포 설정
- Google Play 배포 설정
- Rive/Lottie 에셋 제작

MVP 첫 단계는 Flutter 앱 골격, 디자인 토큰, 홈 화면 UI 스파이크부터 진행한다.
