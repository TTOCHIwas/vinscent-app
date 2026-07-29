# 단짠 iOS 개인정보 선언 기준

이 문서는 iOS 앱과 위젯의 개인정보 매니페스트, App Store Connect의
앱 개인정보 답변, 공개 개인정보처리방침이 서로 어긋나지 않도록 유지하는
내부 기준이다. 기준일은 2026년 7월 29일이다.

## 1. 적용 대상

| 대상 | 매니페스트 | 번들 위치 |
|---|---|---|
| Runner 앱 | `apps/mobile/ios/Runner/PrivacyInfo.xcprivacy` | `Runner.app/PrivacyInfo.xcprivacy` |
| VinscentWidgets 확장 | `apps/mobile/ios/VinscentWidgets/PrivacyInfo.xcprivacy` | `Runner.app/PlugIns/VinscentWidgets.appex/PrivacyInfo.xcprivacy` |

두 파일은 각각의 Xcode target Resources에 포함된다. 앱과 위젯 모두
추적을 하지 않으며 추적 도메인을 선언하지 않는다.

## 2. 필수 사유 API

| 대상 | API 분류 | 사유 코드 | 실제 사용 근거 |
|---|---|---|---|
| Runner | File Timestamp | `C617.1` | App Group 안의 위젯 녹음 임시 파일이 정상 파일인지 크기와 유형을 확인 |
| Runner | User Defaults | `CA92.1` | 앱 자체 설정과 기능 상태를 앱 전용 저장소에서 읽고 씀 |
| Runner | User Defaults | `1C8F.1` | App Group을 통해 위젯 녹음·재생 상태를 위젯과 공유 |
| Widget | File Timestamp | `C617.1` | App Group 안에서 위젯이 만든 녹음 임시 파일의 크기와 유형을 확인 |
| Widget | User Defaults | `1C8F.1` | 동일 App Group에 속한 Runner와 위젯 상태를 공유 |

주요 코드 근거는 다음과 같다.

- `apps/mobile/ios/Runner/VinscentWidgetAudioController.swift`
- `apps/mobile/ios/SharedWidgets/VinscentWidgetShared.swift`
- `apps/mobile/ios/Runner/Runner.entitlements`
- `apps/mobile/ios/VinscentWidgets/VinscentWidgets.entitlements`

사유 코드는 App Group 또는 앱 컨테이너 안의 데이터에만 적용한다. 해당
API가 컨테이너 밖의 파일이나 다른 앱의 기본 설정을 읽도록 확장되면 현재
사유 코드를 그대로 사용하지 않고 다시 검토한다.

## 3. Runner 수집 데이터

아래 항목은 모두 사용자 또는 계정과 연결되며 광고 추적에는 사용하지
않는다.

| Apple 데이터 유형 | 단짠 데이터 | 목적 |
|---|---|---|
| Name | Apple 최초 로그인 이름, 프로필 닉네임 | 앱 기능 |
| Email Address | 로그인 제공자가 전달한 이메일 | 인증과 계정 관리 |
| Coarse Location | 선제 추천 시 저정밀로 축소한 현재 위치 | 제품 개인화 |
| Photos or Videos | 카드 사진과 완성 카드 이미지 | 앱 기능 |
| Audio Data | 현재 녹음과 녹음 슬롯 음성 | 앱 기능 |
| Other User Content | 카드 글·그림, 질문 답변, 일정 메모·그림, 캐릭터 그림, 신고 설명 | 앱 기능, 제품 개인화 |
| Search History | 사용자가 AI에게 직접 입력한 질문 | 앱 기능, 제품 개인화 |
| User ID | Supabase 사용자 ID와 로그인 제공자 식별자 | 인증과 앱 기능 |
| Device ID | 푸시 알림 기기 토큰 | 알림 전달 |
| Product Interaction | AI 추천·피드백 노출 상태와 사용자 결정 | 앱 기능, 제품 개인화 |
| Other Diagnostic Data | AI 작업과 푸시 발송의 상태·지연·오류 | 안정성 및 장애 대응 |
| Other Data Types | 생일, 커플 관계, 정책 동의, 신고·차단·검토 기록 등 위 분류로 충분히 표현되지 않는 데이터 | 앱 기능, 제품 개인화 |

위젯 확장은 App Group에 표시 데이터와 녹음 임시 파일을 저장하지만
독립적으로 서버에 데이터를 전송하지 않는다. 서버 전송은 Runner가
수행하고 Runner 매니페스트에서 해당 수집 유형을 선언한다.

## 4. App Store Connect 답변 원칙

- 앱과 통합한 제3자 SDK의 처리까지 포함해 실제 수집 항목을 모두 답한다.
- 현재 선언된 데이터는 모두 `Linked to You`로 답한다.
- 광고, 데이터 브로커 제공, 교차 앱 추적이 없으므로 `Used to Track You`
  항목은 선택하지 않는다.
- 앱 기능 목적과 제품 개인화 목적은 매니페스트 표와 동일하게 답한다.
- 위치는 서버 전달 전에 소수 둘째 자리로 줄이므로 `Coarse Location`으로
  답한다.
- 자유 입력란과 음성 녹음은 각각 `Other User Content`와 `Audio Data`로
  답한다.
- 앱 코드나 외부 SDK의 데이터 흐름이 바뀌면 앱 업데이트 제출 여부와
  관계없이 App Store Connect 답변도 갱신한다.
- 개인정보 매니페스트는 App Store Connect 앱 개인정보 답변을 대신하지
  않는다.

## 5. Mac 출시 검증

Windows 정적 검증만으로는 최종 archive 안의 제3자 SDK 매니페스트
집계까지 확인할 수 없다. 배포용 Mac에서 다음 절차를 완료한다.

1. 배포할 정확한 버전으로 Xcode에서 `Product > Archive`를 실행한다.
2. Organizer에서 archive를 열고 패키지 안에 Runner와 위젯의
   `PrivacyInfo.xcprivacy`가 각각 한 개씩 있는지 확인한다.
3. Organizer에서 archive를 Control-click하고
   `Generate Privacy Report`를 실행한다.
4. 보고서의 추적, 수집 데이터, 필수 사유 API를 이 문서와 비교한다.
5. 예상하지 못한 SDK 데이터 유형, 추적 도메인, 누락 또는 잘못된 사유
   코드가 있으면 제출 전에 원인을 수정한다.
6. 최종 보고서를 해당 출시 버전의 증빙으로 보관한다.
7. App Store Connect의 앱 개인정보 답변을 보고서와
   `privacy-data-map.md`에 맞춰 입력한다.

## 6. 자동 검증

다음 테스트는 앱과 위젯 매니페스트 존재 여부, target 포함 여부, 선언된
수집 유형과 필수 사유 코드를 검증한다.

```powershell
flutter test test/release/ios_privacy_manifest_test.dart
flutter test test/release/ios_permission_usage_description_test.dart
```

## 7. Apple 공식 자료

- Privacy manifest files:
  https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- Describing data use in privacy manifests:
  https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests
- Describing use of required reason API:
  https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Adding a privacy manifest:
  https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- App privacy details on the App Store:
  https://developer.apple.com/app-store/app-privacy-details/
