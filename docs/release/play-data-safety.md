# Google Play Data safety 입력 검토표

이 문서는 Google Play Console의 Data safety 설문에 입력할 답변을
`privacy-data-map.md`, Android 권한, 앱 의존성, Supabase 처리 흐름과
대조하기 위한 내부 검토표다. 법률 검토와 외부 처리자 계약 확인 전에는
최종 제출 답변으로 사용하지 않는다.

검토 기준일은 2026년 7월 29일이다. 릴리스 후보의 권한, SDK, 서버 처리
흐름이 바뀌면 이 문서와 Play Console 답변을 함께 갱신한다.

## 1. Google Play 판단 기준

- `수집`은 앱이나 SDK가 사용자 데이터를 기기 밖으로 전송하는 것을
  의미한다. 개발자 서버가 아니라 외부 SDK 서버로 보내는 경우도 포함한다.
- 일시적 처리는 수집 설문에 포함해야 한다. 특정 실시간 요청을 처리하는
  동안 메모리에만 두고 요청 완료 후 보관하지 않을 때만 `ephemeral`로
  답할 수 있다.
- 개발자의 지시에 따라 개발자를 대신해 처리하는 서비스 제공자에게
  보내는 데이터는 `공유` 예외가 될 수 있다. 계약과 실제 이용 조건이
  이를 충족하는지는 개발자가 확인해야 한다.
- 사용자가 명확히 시작하고 예상하는 상대방 공유도 Google이 정한 예외에
  해당할 수 있다. 단짠의 커플 공유 콘텐츠는 공개 정책에서 별도로
  설명해야 한다.
- 권한이 선언됐다는 사실만으로 수집이 되는 것은 아니다. 실제로 기기
  밖으로 전송되는 데이터만 해당 유형에 선언한다.
- 앱과 모든 SDK가 전송하는 사용자 데이터에 전송 중 암호화가 적용될
  때만 전체 암호화 질문에 `예`라고 답한다.

공식 기준:

- Data safety:
  https://support.google.com/googleplay/android-developer/answer/10787469
- User Data:
  https://support.google.com/googleplay/android-developer/answer/10144311
- Account deletion:
  https://support.google.com/googleplay/android-developer/answer/13327111

## 2. 설문 첫 화면 답변

| Play Console 질문 | 현재 답변 후보 | 제출 전 조건 |
|---|---|---|
| 앱이 사용자 데이터를 수집하거나 공유하는가 | `예` | 아래 수집 유형을 모두 입력 |
| 모든 사용자 데이터가 전송 중 암호화되는가 | `예` 후보 | 릴리스의 Supabase URL, Gemini 사용자 지정 endpoint, Open-Meteo endpoint가 모두 HTTPS인지 확인하고 SDK 전송 조건 검토 |
| 사용자가 데이터 삭제를 요청할 수 있는가 | `예` 후보 | 앱 내부 계정 삭제와 공개 웹 삭제 요청 경로가 모두 실제로 동작해야 함 |
| 앱에서 계정을 생성할 수 있는가 | `예` | 카카오·Apple 로그인 후 단짠 계정과 프로필이 생성됨 |
| 독립 보안 검토를 완료했는가 | `아니요` | MASA 등 공인 검토를 실제 완료한 경우에만 변경 |

계정 삭제의 앱 내부 경로는 `설정 > 계정 > 계정 삭제`로 구현돼 있다.
Google Play 제출 전에는 앱 또는 개발자명이 표시되고 삭제 요청 방법을
쉽게 찾을 수 있는 `/account-deletion` 페이지를 공개해야 한다. 현재 정책
웹 초안은 요청을 실제로 접수하는 공개 경로가 아니므로 이 조건을 아직
충족하지 않는다.

## 3. 데이터 유형별 답변 후보

`공유`는 아래 표에서 일괄 확정하지 않는다. Supabase, Google, Firebase,
Open-Meteo 등 외부 처리자의 계약상 역할을 5절에서 확인한 뒤 최종
답변한다.

| Google Play 데이터 유형 | 단짠의 실제 데이터 | 수집 | 일시적 처리 | 필수 또는 선택 | 목적 |
|---|---|---:|---:|---|---|
| Approximate location | 선제 추천 시 한 번 조회하는 저정밀 위도·경도 | 예 | 예 | 선택 | Personalization |
| Name | 온보딩에서 필수 입력하는 닉네임, Apple 최초 로그인 이름 | 예 | 아니요 | 닉네임 필수 | App functionality, Account management |
| Email address | Apple 로그인 제공 이메일 또는 비공개 릴레이 주소 | 예 | 아니요 | 로그인 경로에 따라 선택 | Account management |
| User IDs | Supabase 사용자 ID, 로그인 제공자 식별자 | 예 | 아니요 | 필수 | App functionality, Account management, Fraud prevention/security |
| Other info | 필수 생일, 커플 관계·만난 날·연결 상태 | 예 | 아니요 | 생일·커플 설정 필수 | App functionality, Personalization |
| Photos | 카드 사진·완성 이미지, 카드·캐릭터·일정·녹음 슬롯 그림 | 예 | 아니요 | 선택 | App functionality |
| Voice or sound recordings | 현재 녹음과 녹음 슬롯 음성 | 예 | 아니요 | 선택 | App functionality |
| Calendar events | 공유 일정 제목·날짜·반복·메모·그림·알림 설정 | 예 | 아니요 | 선택 | App functionality |
| App interactions | AI 추천·한마디 노출, 기억 확인·거절, 질문 진행 상태 | 예 | 아니요 | AI 이용 여부에 따라 선택 | App functionality, Personalization |
| Other actions | 안전 이용 동의, 신고·차단과 검토 상태 | 예 | 아니요 | 해당 기능 이용 시 수집 | App functionality, Fraud prevention/security |
| Other user-generated content | 카드 글·편집 데이터, 질문 답변, AI 직접 질문, 일정 메모, 신고 상세 설명 | 예 | 아니요 | 선택 | App functionality, Personalization, Fraud prevention/security |
| Diagnostics | AI 작업·푸시 발송의 상태, 지연, 토큰 수, 오류 코드 | 예 | 아니요 | 해당 기능 이용 시 자동 | App functionality, Analytics |
| Device or other IDs | 앱 시작 시 자동 생성되는 Firebase 설치 식별자, 알림 허용 후 등록되는 FCM 기기 토큰과 플랫폼 | 예 | 아니요 | 설치 식별자는 필수, FCM 토큰 등록은 알림 이용 여부에 따라 선택 | App functionality |

### 직접 AI 질문 분류

현재 단짠의 `질문하기`는 앱 안의 콘텐츠를 검색하는 검색 기능이 아니라
사용자가 자유 문장을 AI 처리에 보내는 기능이다. 따라서 이 검토표는
질문 본문을 `Other user-generated content`로 우선 분류한다.

Play Console의 실제 문구나 심사 안내가 AI 질의를 `In-app search history`로
분류하도록 요구하면 두 유형을 모두 선언하고, 공개 정책과 iOS App Privacy
답변도 같은 데이터 흐름을 설명하도록 갱신한다.

### 필수·선택 판단 주의

- 닉네임과 생일은 온보딩 완료 조건이므로 필수다.
- 사용자 ID는 로그인과 모든 커플 기능에 필요하므로 필수다.
- 사진, 녹음, 일정, 자유 입력 콘텐츠와 AI는 사용자가 기능을 선택할 때만
  전송되므로 선택 수집 후보로 둔다.
- Firebase 설치 식별자는 앱 시작 시 Firebase가 초기화되면서 자동
  생성되므로 `Device or other IDs` 데이터 유형은 필수 수집으로 답한다.
- 단짠 서버에 FCM 토큰을 등록하는 흐름은 알림 권한과 설정 상태에 따라
  선택적으로 실행된다. 이 차이는 데이터 유형의 필수·선택 답변을
  Firebase 설치 식별자 기준으로 판단한 뒤 기능 설명에 별도로 남긴다.

## 4. 선택하지 않을 데이터 유형

현재 코드와 의존성에서 다음 데이터의 의도적 수집 흐름은 확인되지 않았다.

- Precise location
- Address, Phone number
- Race and ethnicity, Political or religious beliefs, Sexual orientation
- Financial info, Purchase history
- Health and fitness
- Emails, SMS or MMS, Other in-app messages
- Videos, Music files, Other audio files
- Files and docs, Contacts
- Installed apps, Web browsing history
- Crash logs, Other app performance data

사용자가 자유 입력 답변이나 신고 설명에 민감한 내용을 자발적으로 적을
수는 있다. 앱은 이를 구조화된 민감 유형으로 요구하지 않으며, 별도 동의
없는 민감 기억 활성화를 차단한다. 공개 전에는 실제 고정 질문과 Gemini
처리 조건이 민감 정보를 의도적으로 수집·추론하지 않는지 다시 검토한다.

Firebase Core와 Messaging은 사용하지만 Crashlytics와 Analytics SDK는
의존성에 없다. 따라서 현재 빌드만을 기준으로 Crash logs를 선택하지
않는다. SDK 구성이나 의존성이 바뀌면 다시 판단한다.

## 5. 공유 여부 확인표

Google Play의 `공유` 답변은 아래 확인이 모두 끝난 뒤 확정한다.

| 외부 처리자 또는 수신자 | 전송 데이터 | 현재 예상 분류 | 제출 전 증거 |
|---|---|---|---|
| Supabase | 계정, 커플 콘텐츠, AI·알림·안전 데이터 | 서비스 제공자 후보 | 계약 주체, DPA, 처리 리전과 보관 조건 |
| Google Gemini API | 질문·답변, 확인된 기억, 최근 문맥 | 서비스 제공자 후보 | Cloud Billing, 적용 약관, 데이터 사용·보관·학습 제외 조건 |
| Firebase Installations·Cloud Messaging | Firebase 설치 식별자, SDK 앱·OS·기기 환경 정보, FCM 토큰, 알림 내용과 라우팅 데이터 | 서비스 제공자 후보 | Firebase 적용 약관과 데이터 처리·보관·삭제 조건 |
| Open-Meteo | 소수 둘째 자리로 줄인 위도·경도 | 서비스 제공자 또는 명시적 사용자 동의 예외 검토 | 상업 이용 계약·요금제, 처리·보관 조건 |
| Kakao·Apple | 로그인 요청, OAuth/OIDC 토큰과 인증 코드 | 사용자 시작 인증 흐름 | 각 로그인 약관과 앱 공개 설명 |
| 연결된 상대방 | 사용자가 올린 카드·답변·녹음·일정 | 사용자가 시작하고 예상하는 전송 후보 | 작성 화면과 공개 정책의 커플 공유 설명 |

하나라도 Google의 서비스 제공자 또는 다른 공유 예외를 충족하지 않으면
해당 데이터 유형을 `공유함`으로 선언한다. 단순히 광고 SDK가 없다는
이유만으로 `공유 안 함`을 선택하지 않는다.

## 6. 보안과 삭제 답변 근거

### 전송 중 암호화

코드에 고정된 Gemini, Open-Meteo, FCM, Apple endpoint는 HTTPS다.
Android 릴리스 CI는 `POLICY_BASE_URL`도 HTTPS만 허용한다. 다음 값은
환경에서 주입되므로 릴리스별로 별도 확인한다.

- `SUPABASE_URL`
- `GEMINI_GENERATE_CONTENT_ENDPOINT`
- `OPEN_METEO_ENDPOINT`

XML namespace의 `http://schemas.android.com`은 네트워크 전송 endpoint가
아니므로 암호화 판단 대상이 아니다.

### 삭제 요청

- 앱 내부 계정 삭제는 관계형 데이터와 Auth 사용자를 삭제하고 Storage
  객체를 비동기 정리 큐로 보낸다.
- Apple 로그인 사용자는 재인증과 Apple 권한 철회를 거친다.
- 사용자가 속한 커플의 공유 카드·녹음·답변·캐릭터·일정·AI 데이터도
  계정 삭제 범위에 포함한다.
- 연결된 상대방의 개인 계정 자체는 삭제하지 않는다.
- 외부 웹 경로는 본인 확인 방법, 접수 채널, 예상 처리 기간과 예외적
  보관 항목을 명시하고 실제 요청을 접수할 수 있어야 한다.

## 7. Console 입력 전 차단 조건

- [ ] 법적 운영자명과 개인정보 문의 이메일 확정
- [ ] 공개 `/privacy`와 `/account-deletion` 배포 및 실제 요청 접수 확인
- [ ] 외부 처리자별 서비스 제공자 여부와 국외 이전 조건 확인
- [ ] Gemini Cloud Billing과 데이터 보관·학습 이용 조건 확인
- [ ] Open-Meteo 상업 이용 계약과 데이터 처리 조건 확인
- [ ] AI·알림 진단 및 신고 기록 보관기간 확정
- [ ] 릴리스 환경의 모든 사용자 데이터 endpoint가 HTTPS인지 확인
- [ ] 알림 권한 거절 시 단짠 서버에 FCM 토큰이 등록되지 않는지 Android 실기기에서 확인
- [ ] 계정 삭제 후 Database, Auth, Storage 정리 큐와 기기 캐시 제거 확인
- [ ] Play Console 작성 후 답변 CSV와 Store listing preview를 출시 증빙에 보관
- [ ] 공개 개인정보처리방침, 이 문서, App Store App Privacy 답변 상호 대조

## 8. 저장소 근거

- `docs/release/privacy-data-map.md`
- `docs/release/ios-privacy-declaration.md`
- `apps/mobile/android/app/src/main/AndroidManifest.xml`
- `apps/mobile/pubspec.yaml`
- `apps/mobile/lib/features/onboarding/application/onboarding_state.dart`
- `apps/mobile/lib/features/profile/data/profile_repository.dart`
- `apps/mobile/lib/features/ai/application/ai_current_location_service.dart`
- `apps/mobile/lib/features/ai/data/ai_proactive_suggestion_repository.dart`
- `apps/mobile/lib/features/notifications/data/push_token_repository.dart`
- `supabase/functions/delete-account/`
- `supabase/functions/_shared/fcm.ts`
- `services/ai-api/src/infrastructure/gemini-structured-generation-client.ts`
- `services/ai-api/src/infrastructure/open-meteo-forecast-client.ts`
- `supabase/migrations/20260729002000_add_account_shared_data_deletion.sql`
- `supabase/migrations/20260729004000_add_private_safety_reports.sql`
- `supabase/migrations/20260729006000_add_user_blocking.sql`
