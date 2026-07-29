# 스토어 제출 체크리스트

이 문서는 단짠 `1.0.0` 출시를 위해 저장소 자동 검증, 운영 결정, Google
Play Console, App Store Connect에서 완료해야 하는 항목을 한곳에 정리한다.
체크 표시에는 빌드 로그, 화면 캡처, Console 상태 또는 테스트 결과가
근거로 남아 있어야 한다.

## 1. 공통 출시 차단 조건

- [ ] 법적 운영자명, 개인정보 문의 이메일, 정책 시행일 확정
- [ ] 서비스 최저 이용 연령 확정
- [ ] Gemini Cloud Billing과 데이터 처리 조건 확정
- [ ] 상업 이용 가능한 날씨 API 계약·엔드포인트 확정
- [ ] AI·알림 진단 로그와 신고 기록 보관기간 확정
- [ ] 신고 운영 채널, 담당자, 검토 목표 시간 확정
- [ ] `/privacy`, `/terms`, `/safety`, `/account-deletion` 공개 배포
- [ ] 앱 설정에서 개인정보처리방침과 이용약관 URL 연결
- [ ] 공개 정책, `play-data-safety.md`, App Store App Privacy 답변 일치
- [ ] CI의 Flutter, iOS, Node, Edge, Database 작업이 원격에서 통과
- [ ] `docs/release/mobile-performance-baseline.md`의 실기기 검증 통과
- [ ] `docs/release/mobile-release-qa.md`의 출시 후보 QA 통과

정책 웹 공개 조건과 미확정 운영 정보는
`docs/release/policy-web-release-gates.md`를 따른다.

## 2. Android 제출

### 개발자 계정과 테스트

- [ ] Play 개인 개발자 계정 본인 확인 완료
- [ ] Play Console에 앱을 만들고 package name
  `com.vinscent.vinscent` 고정
- [ ] 내부 테스트에서 설치·업데이트·로그인 smoke test 완료
- [ ] 최소 12명의 tester가 비공개 테스트에 14일 연속 opt-in
- [ ] 비공개 테스트 피드백, 수정 내용, 출시 준비 판단 근거 기록
- [ ] 비공개 테스트 완료 후 프로덕션 접근 신청 승인

2023-11-13 이후 생성된 개인 계정은 12명·14일 비공개 테스트를 충족하기
전까지 Production과 Open testing을 사용할 수 없다.

### 앱 콘텐츠 선언

- [ ] 앱 또는 게임: 앱
- [ ] 무료 또는 유료: 초기 출시 정책에 맞게 선택
- [ ] 광고 포함 여부: 광고 SDK가 없는 현재 빌드는 `아니요`
- [ ] App access에 두 테스트 계정과 커플 연결 절차 제공
- [ ] 대상 연령과 콘텐츠 등급 설문 완료
- [ ] 개인정보처리방침 URL 등록
- [ ] Data safety에 `play-data-safety.md`의 검토 완료 답변 반영
- [ ] 계정 삭제 질문에 앱 내부 경로와 외부 삭제 URL 등록
- [ ] AI 생성 콘텐츠, UGC 신고·차단·운영 검토 흐름을 review note에 설명
- [ ] coarse location의 일회성 날씨 추천 목적을 정확히 선언
- [ ] 카메라, 마이크, 사진 저장, 알림 권한의 사용자 기능 설명

### Foreground service 선언

현재 Android manifest에는 위젯 녹음과 재생을 위해 다음 유형이 있다.

- `microphone`: 홈 화면 위젯에서 사용자가 누른 녹음 버튼으로 시작하는
  음성 녹음
- `mediaPlayback`: 캐릭터·슬롯 음성을 백그라운드에서 이어 재생

Play Console의 App content에서 두 foreground service 유형마다 다음을
제출한다.

- [ ] 기능 설명
- [ ] 즉시 실행되지 않거나 중단될 때 사용자에게 생기는 영향
- [ ] 앱 또는 위젯에서 기능을 시작하고 종료하는 전체 시연 영상 URL
- [ ] 사용자 시작·인지 가능·중지 가능 조건에 대한 설명

### Store listing

한국어 문구, 스크린샷 순서와 심사 재현 절차는
`docs/release/store-listing-copy-ko.md`를 기준으로 준비한다.

- [ ] 앱 이름 `단짠` 확인, 30자 이하
- [ ] 짧은 설명 작성, 80자 이하
- [ ] 전체 설명 작성, 4,000자 이하
- [ ] 지원 이메일 등록
- [ ] 정책·지원 웹사이트 URL 등록
- [ ] 앱 아이콘과 feature graphic 제작
- [ ] 실제 기능을 보여주는 휴대전화 screenshot 제작
- [ ] 태블릿 지원 화면 screenshot 제작
- [ ] 카테고리와 tag 선택
- [ ] 한국어를 기본 언어로 지정하고 자동 번역 의존 여부 결정

### Artifact

- [ ] Android upload key를 암호화된 별도 보관소에 백업
- [ ] GitHub `android-release` Environment에 7개 빌드 secret과
  `DANJJAN_POLICY_BASE_URL` 공개 변수 등록
- [ ] Play App Signing 활성화
- [ ] `versionCode`가 이전 업로드보다 큼
- [ ] `Android release candidate` workflow로 서명된 Release AAB 생성
- [ ] mapping file과 native debug symbols 보관·업로드
- [ ] workflow artifact의 AAB·mapping SHA-256과 commit SHA 보관
- [ ] App Bundle Explorer에서 기기별 다운로드 크기 확인
- [ ] Pre-launch report의 crash, ANR, 접근성, 보안 경고 처리
- [ ] 내부 또는 비공개 track에서 최종 AAB 업데이트 검증

```powershell
apps/mobile/flutterw.cmd build appbundle --release --analyze-size
```

## 3. iOS 제출

### Apple Developer와 App Store Connect

- [ ] Apple Developer Program 등록과 계약·세금·금융 상태 확인
- [ ] App ID `com.vinscent.vinscent` 생성
- [ ] Widget App ID `com.vinscent.vinscent.widgets` 생성
- [ ] App Group `group.com.vinscent.vinscent` 생성·연결
- [ ] Runner의 Push Notifications, Sign in with Apple, Background Modes 연결
- [ ] Firebase에 APNs authentication key, Key ID, Team ID 등록
- [ ] App Store Connect app record 생성
- [ ] TestFlight 내부 tester 설치와 실제 iPhone 검증

capability와 archive 검증은
`docs/release/mobile-signing-and-capabilities.md`를 따른다.

### App information과 privacy

- [ ] 이름, subtitle, 기본 언어, category, age rating 입력
- [ ] Support URL과 Privacy Policy URL 입력
- [ ] App Privacy에 앱과 모든 제3자 SDK의 수집·사용 데이터 입력
- [ ] 콘텐츠 권리와 암호화 수출 규정 질문 답변
- [ ] UGC·AI 기능, 신고·차단, review용 테스트 계정을 review note에 설명
- [ ] 카메라·마이크·사진·위치·알림 권한 설명과 실제 동작 일치
- [ ] Runner와 위젯의 archive Privacy Report 검증

App Privacy 세부 답변은
`docs/release/ios-privacy-declaration.md`와 `privacy-data-map.md`를 따른다.

### Product page와 build

- [ ] 설명, keyword, copyright 작성
- [ ] 지원하는 iPhone 크기의 실제 screenshot 등록
- [ ] iPad 지원 화면 screenshot 등록
- [ ] 앱 아이콘과 화면이 실제 출시 build와 일치
- [ ] version `1.0.0`, build number가 App Store Connect에서 고유함
- [ ] Distribution 서명 archive 생성
- [ ] `build_ios_release_candidate.sh`에 정책 URL을 포함한 런타임 값 주입
- [ ] IPA·xcarchive·SHA-256·commit SHA 증빙 보관
- [ ] Runner의 production push entitlement 확인
- [ ] 위젯에는 App Group 이외의 불필요한 entitlement가 없음
- [ ] archive validation 통과 후 build upload
- [ ] 처리된 build를 TestFlight에서 설치해 최종 smoke test

## 4. Review 계정과 재현 절차

심사자는 두 명이 연결되어야 핵심 기능을 볼 수 있으므로 다음 자료를
별도로 준비한다.

- [ ] 만료되지 않는 review 계정 2개
- [ ] 로그인 제공자별 접근 방법
- [ ] 두 계정을 연결하는 코드와 만난 날 설정 절차
- [ ] 카드·질문·답변이 보이는 준비된 데이터
- [ ] AI 동의와 개인화 완료 상태를 확인할 수 있는 계정
- [ ] 위젯 추가·녹음 권한·재생 절차
- [ ] 신고, 차단, 계정 삭제 진입 경로
- [ ] 네트워크 작업에 시간이 걸리는 기능과 예상 대기 시간

비밀번호, OAuth 비밀키, service role key는 review note나 저장소에 넣지
않는다.

## 5. 출시 증빙

출시 후보마다 다음 자료를 한 폴더 또는 release ticket에 보관한다.

- commit SHA, 앱 version·build number
- CI 실행 URL
- Android AAB SHA-256, mapping, size analysis
- iOS archive validation과 Privacy Report
- 기기·OS별 QA 결과
- 시작 시간·frame·memory 성능 결과
- Play Pre-launch report
- TestFlight tester 결과
- Data safety와 App Privacy 제출 화면
- 정책 URL과 시행일
- 비공개 테스트 피드백 요약과 반영 내역

## 6. 공식 자료

- Google Play 앱 생성과 listing:
  https://support.google.com/googleplay/android-developer/answer/9859152
- 새 개인 계정 테스트 요구사항:
  https://support.google.com/googleplay/android-developer/answer/14151465
- Google Play Data safety:
  https://support.google.com/googleplay/android-developer/answer/10787469
- Google Play 계정 삭제:
  https://support.google.com/googleplay/android-developer/answer/13327111
- Foreground service 선언:
  https://support.google.com/googleplay/android-developer/answer/13392821
- App Store Connect 필수 속성:
  https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
- App Store app privacy:
  https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
- App Store build upload:
  https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
