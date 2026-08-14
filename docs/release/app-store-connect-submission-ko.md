# 단짠 App Store Connect 입력 기준

이 문서는 단짠 `1.0.0`의 App Store Connect 한국어 입력값을 Google Play
등록 정보와 같은 사실에 맞추기 위한 기준이다. Apple과 Google의 필드명,
글자 제한 또는 데이터 분류가 다른 경우에만 표현을 바꾼다. 기능, 최저 이용
연령, 데이터 처리와 안전 정책은 스토어마다 다르게 선언하지 않는다.

스크린샷과 앱 미리보기는 실제 출시 후보의 심사용 계정 데이터가 준비된 뒤
별도로 등록한다. 그 밖의 입력은 이 문서를 기준으로 먼저 완료한다.

## 1. 앱 레코드와 배포 기본값

| App Store Connect 필드 | 입력값 |
|---|---|
| 플랫폼 | iOS |
| 이름 | `단짠` |
| 기본 언어 | 한국어 |
| 번들 ID | `com.vinscent.vinscent` |
| SKU | `danjjan-ios` |
| 앱 또는 게임 | 앱 |
| 버전 | `1.0.0` |
| 가격 | 무료 |
| 기본 카테고리 | 라이프스타일 (`LIFESTYLE`) |
| 추가 카테고리 | 소셜 네트워킹 (`SOCIAL_NETWORKING`) |

기본 카테고리는 Google Play의 라이프스타일 분류와 맞춘다. 단짠은 공개
피드나 사용자 탐색이 없는 1:1 커플 앱이므로 소셜 네트워킹은 추가
카테고리로만 사용한다. 인앱 구입과 구독은 현재 출시 후보에 없다.

출시 국가는 Google Play에서 선택한 국가와 동일하게 맞춘다. 국가 목록은
스토어 외부에서 추정하지 않고 두 Console의 실제 선택 화면을 대조한다.
대한민국 기반 계정은 App Store Connect의 `비즈니스 > 계약 > 규정 준수 >
대한민국 법률`에서 이메일과 전화번호 인증 상태를 확인한다.

## 2. 제품 페이지 한국어

문구의 단일 원본은 `docs/release/store-listing-copy-ko.md`다.

| App Store Connect 필드 | 원본 |
|---|---|
| 이름 | `1. 공통 이름 > 앱 이름` |
| 부제 | `3. App Store > 부제` |
| 프로모션 텍스트 | `3. App Store > 프로모션 텍스트` |
| 설명 | `2. Google Play > 전체 설명`과 정확히 같은 `3. App Store > 설명` |
| 키워드 | `3. App Store > 키워드` |
| 저작권 | `2026 조준희` |

Google Play의 짧은 설명은 App Store 부제의 30자 제한을 넘을 수 있으므로
의미를 유지한 짧은 부제를 사용한다. 전체 설명은 두 스토어에서 글자와
문단까지 동일하게 유지하며 자동 검증기가 차이를 실패로 처리한다.

| URL 필드 | 입력값 |
|---|---|
| 지원 URL | `https://danjjan-policy.pages.dev/support` |
| 개인정보 처리방침 URL | `https://danjjan-policy.pages.dev/privacy` |
| 사용자 개인정보 선택 URL | `https://danjjan-policy.pages.dev/account-deletion` |
| 마케팅 URL | 비워 둠 |

지원 URL에는 실제 문의 이메일과 계정 삭제 경로가 공개돼 있다. 마케팅
전용 사이트가 없으므로 정책 웹을 마케팅 URL로 오인해 입력하지 않는다.

## 3. 연령 등급

Google Play와 동일하게 서비스 가입과 이용은 만 14세 이상이다. Apple의
질문은 Google의 대상 연령 설문과 이름이 다르므로 다음과 같이 실제 기능을
기준으로 답한다.

### 앱 내 제어 및 기능

| 질문 | 답변 | 근거 |
|---|---|---|
| 자녀 보호 기능 | 아니요 | 보호자용 관리 도구가 없음 |
| 연령 확인 | 예 | 생년월일 입력과 서버 검증으로 만 14세 미만 가입을 차단 |
| 제한 없는 웹 접근 | 아니요 | 앱 안에서 임의 웹 탐색을 제공하지 않음 |
| 사용자 생성 콘텐츠 | 아니요 | Apple 정의의 광범위 배포가 없고 연결된 한 명에게만 공유 |
| 소셜 미디어 | 아니요 | 공개 피드, 검색, 팔로우, 재배포가 없음 |
| 13세 미만 소셜 미디어 차단 | 아니요 | 소셜 미디어 기능 자체가 없음 |
| 메시지 및 채팅 | 예 | 연결된 두 사용자가 카드, 글, 답변과 음성을 직접 공유 |
| 광고 | 아니요 | 광고 SDK와 광고 노출이 없음 |

Apple 연령 설문의 `사용자 생성 콘텐츠`는 광범위하게 배포되는 콘텐츠를
뜻한다. 이 항목을 `아니요`로 답해도 App Privacy의 사진·음성·기타 사용자
콘텐츠 수집 선언과 심사 메모의 1:1 공유 콘텐츠 설명은 그대로 유지한다.

### 콘텐츠 빈도

다음 항목은 모두 `없음` 또는 `아니요`다.

- 욕설 또는 저속한 유머, 공포 또는 두려움
- 주류, 담배 또는 약물 사용이나 언급
- 의료 또는 치료 정보, 건강 또는 웰니스 주제
- 성숙하거나 선정적인 주제, 성적 콘텐츠 또는 노출
- 만화·판타지 폭력, 사실적 폭력, 장시간의 잔혹한 폭력, 무기
- 도박, 모의 도박, 대회, 전리품 상자

사용자가 자유 입력란에 금지 콘텐츠를 올릴 가능성은 고정 앱 콘텐츠의
빈도로 과장하지 않는다. 대신 안전 이용 약속, 신고, 차단과 운영 검토
절차를 심사 메모에 설명한다.

설문만 계산하면 iOS 26 이상에서 글로벌 `4+`, 대한민국 `전체 이용가`가
나올 수 있다. 그러나 서비스 약관의 최저 연령은 만 14세이므로 Apple의
`연령 카테고리 및 재정의`에서 더 높은 등급을 적용해야 한다. Apple에
정확한 `14+` 선택지가 없으므로 다음 중 하나를 출시 책임자가 확정한다.

- `16+`: 만 14세 미만에게 노출하지 않는 보수적 선택이지만 14~15세 이용
  가능 정책보다 높다.
- `13+`: 만 14세 정책에 가장 가까운 선택이지만 13세에게도 적합하다고
  표시될 수 있다.

정책의 만 14세 기준을 바꾸지 않은 상태에서는 `16+`를 권장한다. 선택한
값과 Google Play의 대상 연령 설정 차이는 출시 증빙에 남긴다.

## 4. App Privacy

앱과 통합한 SDK를 포함해 데이터 수집 여부는 `예`, 추적은 `아니요`로
답한다. 아래 항목은 모두 사용자와 연결되며 `추적에 사용`은 선택하지
않는다.

| Apple 데이터 유형 | 목적 |
|---|---|
| 이름 | 앱 기능 |
| 이메일 주소 | 앱 기능 |
| 대략적 위치 | 제품 개인화 |
| 사진 또는 비디오 | 앱 기능 |
| 오디오 데이터 | 앱 기능 |
| 기타 사용자 콘텐츠 | 앱 기능, 제품 개인화 |
| 검색 기록 | 앱 기능, 제품 개인화 |
| 사용자 ID | 앱 기능 |
| 기기 ID | 앱 기능 |
| 제품 상호 작용 | 앱 기능, 제품 개인화 |
| 기타 진단 데이터 | 앱 기능 |
| 기타 데이터 유형 | 앱 기능, 제품 개인화 |

Apple의 `검색 기록`은 사용자가 AI에 직접 입력한 자유 질문을 분류하기
위한 항목이다. Google Play에서는 같은 데이터를 `기타 사용자 생성
콘텐츠`로 분류하므로 데이터 흐름이 달라지는 것은 아니다. App Privacy
답변은 `docs/release/ios-privacy-declaration.md`와
`docs/release/privacy-data-map.md`를 함께 대조한다.

## 5. 콘텐츠 권리와 수출 규정

콘텐츠 권리 질문은 `예, 제3자 콘텐츠를 포함하거나 표시하거나 접근함`으로
답하고, 해당 콘텐츠에 필요한 권리를 보유했음을 확인한다. 연결 상대방의
사용자 콘텐츠는 이용약관상 자신이 만들었거나 적법하게 사용할 수 있는
콘텐츠만 올리도록 제한한다. 날씨 데이터는 MET Norway의 공개 이용 조건과
출처 표시를 따른다.

앱은 HTTPS, Apple·Kakao 로그인, OS 보안 저장소와 SDK의 공개 표준
암호화만 사용하며 자체 비공개 암호화 알고리즘을 구현하지 않는다. 현재
출시 후보는 수출 규정 문서 제출이 필요한 비면제 암호화를 사용하지 않는
것으로 분류하고 Runner `Info.plist`에
`ITSAppUsesNonExemptEncryption = NO`를 선언한다. 의존성 또는 암호화 기능이
바뀌면 다시 검토한다.

## 6. 심사 정보

연락처 이름, 전화번호와 이메일은 App Store Connect 계정의 실제 담당자
정보를 사용하고 저장소에 복제하지 않는다. 로그인 없이 핵심 기능을 볼 수
없으므로 제출 시 유효한 심사용 계정 정보를 반드시 제공한다.

심사 메모 기준안:

> 단짠은 이미 교제 중인 두 사용자가 연결 코드를 통해 1:1 공간을 만든 뒤
> 카드, 질문 답변, 일정과 짧은 음성을 공유하는 앱입니다. 공개 피드, 사용자
> 검색, 불특정 다수 공유, 광고와 인앱 구입은 없습니다.
>
> 제공한 첫 번째 심사용 계정은 두 번째 심사용 계정과 연결된 상태이며 홈,
> 카드, 질문, 캘린더, 녹음과 AI 탭에 검토용 데이터가 준비돼 있습니다.
> AI 기능은 두 사용자의 동의 뒤에 활성화되고 생성 결과에는 AI 표시와 신고
> 진입점이 제공됩니다. 서버의 비동기 생성은 네트워크 상태에 따라 수 분이
> 걸릴 수 있습니다.
>
> 공유 콘텐츠 작성 전 안전 이용 약관 동의가 필요합니다. 각 콘텐츠의
> 더보기 메뉴에서 신고할 수 있고 설정에서 상대방 차단, 커플 연결 해제와
> 계정 삭제를 수행할 수 있습니다. 신고는 비공개 운영 채널에서 검토합니다.
>
> 개인정보처리방침과 고객지원은 설정에서 열 수 있으며 계정 삭제 경로는
> 설정 > 계정 > 계정 삭제입니다. 위젯은 iOS 홈 화면의 위젯 추가 메뉴에서
> 단짠을 선택해 확인할 수 있습니다.

계정 ID, 비밀번호와 연결 코드는 App Store Connect의 전용 심사 필드에만
입력한다. 저장소, 첨부 문서 또는 일반 심사 메모에는 넣지 않는다.

## 7. 스크린샷과 별도로 남는 결정

다음 항목은 스크린샷 없이 처리할 수 있지만 계정 소유자의 실제 정보나
사업 결정이 필요하므로 추정 입력하지 않는다.

- Apple 연령 등급 재정의 `13+` 또는 `16+` 최종 선택
- Google Play와 동일한 출시 국가 목록 확인
- EU 배포 시 DSA trader 여부와 공개 연락처 검증
- 대한민국 법률 연락처의 이메일·전화번호 인증
- 심사용 두 계정과 담당자 전화번호 입력
- Apple Guideline 1.2에 설명할 게시 전 필터링 방법과 실제 동작 확정

## 8. 자동 검증

```bash
cd apps/mobile
flutter test test/release/store_listing_copy_validator_test.dart \
  test/release/store_listing_copy_test.dart \
  test/release/ios_release_capabilities_test.dart
dart run tool/verify_store_listing_copy.dart
plutil -lint ios/Runner/Info.plist
```

## 9. Apple 공식 자료

- App information:
  https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
- Platform version information:
  https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- Age ratings:
  https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
- App privacy:
  https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- Export compliance:
  https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
- Korea compliance:
  https://developer.apple.com/kr/help/app-store-connect/manage-compliance-information/manage-korea-compliance-information/
