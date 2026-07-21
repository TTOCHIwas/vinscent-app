# 코드 구조와 검증 기준

작성일: 2026-07-22

이 문서는 현재 코드에 적용된 책임 경계와 회귀 검증 절차를 기록한다. 제품 전체 구성과 기술 결정은 `docs/architecture.md`를 따른다.

## 1. 기본 구조

모바일 앱은 기능 단위(feature-first)로 구성한다.

```text
presentation -> application -> contract / data model
                                ^
                                |
                         external adapter
```

- `presentation`: 화면, 위젯, 사용자 입력 전달, 화면 수명주기를 담당한다.
- `application`: 기능의 상태 전이와 유스케이스 조합을 담당한다.
- `data`의 contract와 model: 기능이 사용하는 데이터 계약과 값을 정의한다.
- Supabase, 파일 시스템, 플러그인, 네이티브 플랫폼 코드는 contract를 구현하는 adapter다.
- 다른 feature의 구현 파일을 직접 가져와 순환 의존성을 만들지 않는다.
- 둘 이상의 feature에서 사용하는 안정된 계약과 UI만 `core`로 올린다.

`core`는 모든 코드를 모으는 공용 폴더가 아니다. 특정 기능의 정책이나 Supabase 구현은 해당 feature에 둔다.

## 2. 현재 적용된 책임 경계

### 모바일

- 공용 드로잉 상태, 스타일, painter, canvas, toolbar는 `core/drawing`이 담당한다.
- 스토리 카드 편집 화면은 화면 조합만 담당하고, 편집 상태와 전이는 `story_card_editor_session` 및 controller가 담당한다.
- 홈 녹음 그림은 layer, item, trash target, drag session, placement geometry로 역할을 나눈다.
- 스토리와 녹음 조회 repository는 외부 I/O와 오류 변환을 담당한다.
- RPC row 해석은 Supabase를 모르는 순수 mapper가 담당한다.
- 앱 시작, 위젯 launch 처리, redirect, 동기화 예약은 각각의 coordinator 또는 scheduler가 담당한다.

### Edge Functions

- webhook 인증과 payload 추출은 `_shared/webhook.ts`가 담당한다.
- 환경 변수 검증은 `_shared/environment.ts`가 담당한다.
- Supabase admin client 생성은 `_shared/supabase.ts`가 담당한다.
- FCM 요청 생성과 응답 해석은 `_shared/fcm.ts`가 담당한다.
- `_shared/push.ts`는 위 모듈을 조합해 알림 전송 흐름을 실행한다.

### Android 홈 위젯

- Worker는 Android 작업 실행과 업로드 orchestration을 담당한다.
- 입력값, 재시도 횟수, 소유 경로, 파일 크기 검증은 순수 policy 객체가 담당한다.
- Android 앱 모듈 테스트는 `:app:testDebugUnitTest`로 실행한다. 루트 `testDebugUnitTest`는 외부 Flutter plugin의 자체 테스트까지 포함할 수 있으므로 제품 회귀 기준으로 사용하지 않는다.

## 3. 변경 규칙

1. 기존 동작을 characterization test로 먼저 고정한다.
2. 순수 정책, mapper, session을 만든 뒤 기존 caller가 이를 사용하도록 위임한다.
3. UI와 외부 I/O를 한 커밋에서 동시에 변경하지 않는다.
4. DB RPC 반환 컬럼을 바꾸면 SQL 계약 테스트와 Dart mapper 테스트를 함께 수정한다.
5. 기능 간 import가 새로 생기면 공용 계약인지 feature 구현 의존인지 먼저 구분한다.
6. 작은 단위마다 관련 테스트를 통과시키고 커밋한 뒤 전체 회귀 검증을 수행한다.

## 4. 검증 명령

### Flutter

```powershell
cd D:\vinscent\apps\mobile
D:\vinscent\scripts\flutter.cmd test
D:\vinscent\scripts\flutter.cmd analyze
```

### Android 앱 모듈

```powershell
cd D:\vinscent\apps\mobile\android
.\gradlew.bat :app:testDebugUnitTest
```

### Supabase DB

로컬 Supabase가 실행 중인 상태에서 수행한다.

```powershell
cd D:\vinscent
cmd /c npx --yes supabase@latest test db
```

### Edge Functions

```powershell
cd D:\vinscent
node --test supabase/tests/functions/environment.test.ts supabase/tests/functions/webhook.test.ts supabase/tests/functions/fcm.test.ts
Get-ChildItem supabase/functions -Recurse -Filter *.ts | ForEach-Object { node --check $_.FullName }
```

### AI API

```powershell
cd D:\vinscent\services\ai-api
cmd /c npm test
```

## 5. 플랫폼 검증 한계

- Windows에서는 iOS/WidgetKit 코드를 빌드하거나 실행할 수 없다. 최종 검증에는 macOS와 Xcode가 필요하다.
- 마이크, 백그라운드 녹음, Android/iOS 홈 위젯, FCM 수신은 실기기에서 최종 확인한다.
- DB와 Edge 단위 테스트 통과만으로 원격 프로젝트의 secret, webhook URL, 배포 버전이 올바르다고 단정하지 않는다.
- 플랫폼 검증을 수행하지 못한 경우 완료 보고에 잔여 위험을 명시한다.
