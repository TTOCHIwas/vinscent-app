# 단짠 개인정보 데이터 맵

이 문서는 앱 코드, Supabase migration, Edge Function을 기준으로 확인한
개인정보 처리 흐름의 내부 기준 문서다. 공개 개인정보처리방침과 스토어
데이터 공개 항목은 이 문서와 일치해야 한다.

## 1. 수집 및 생성 데이터

| 분류 | 실제 데이터 | 처리 목적 | 저장 위치 |
|---|---|---|---|
| 계정 및 인증 | Supabase 사용자 ID, 소셜 로그인 제공자와 제공자 식별자, Apple이 최초 제공하는 이메일·이름 | 로그인, 계정 식별, Apple 계정 삭제 시 토큰 철회 | Supabase Auth |
| 프로필 | 닉네임, 생일 | 앱 표시, 온보딩, 커플 캘린더의 기본 생일 일정 | Supabase Database |
| 커플 관계 | 초대 코드, 두 사용자 ID, 만난 날, 시간대, 연결·해제·차단 상태 | 커플 연결, 공유 날짜 계산, 접근 제어, 보관 및 재연결 | Supabase Database |
| 카드 | 카드 이미지, 사진, 그림, 텍스트, 편집 장면 데이터, 작성자와 작성일 | 커플 카드 작성·공유·다운로드 | Supabase Database·Storage |
| 질문과 답변 | 고정·AI 질문, 두 사용자의 답변, 답변 시각 | 커플 질문 기능, 기록 조회, AI 학습과 피드백 | Supabase Database |
| 녹음 | 음성 파일, 길이, 작성자, 슬롯 제목, 슬롯 그림과 홈 배치 | 음성 녹음·재생·보관·홈 배치·위젯 | Supabase Database·Storage, 기기 임시 저장소 |
| 커플 캐릭터 | 그림 미리보기와 편집 데이터, 마지막 수정자 | 커플 캐릭터 표시·수정·위젯 | Supabase Database·Storage |
| 공유 일정 | 제목, 날짜, 반복 여부, 메모, 그림, 개인별 알림 여부·시점 | 공유 일정 관리, 캘린더 표시, 일정 알림 | Supabase Database·Storage |
| AI 동의 및 학습 | AI 동의 상태, 기억 후보, 근거 답변 ID, 신뢰도, 확인·거절 결정, 개인화 상태 | 단계별 개인화와 사용자 검토 | Supabase Database |
| AI 질문과 결과 | 직접 질문, AI 답변, 한마디, 추천 질문, 선제 추천 노출 횟수 | AI 질문·피드백·추천 제공과 중복·쿼터 제어 | Supabase Database, 일부 기기 캐시 |
| AI 실행 진단 | 작업 종류, 모델, 프롬프트 버전, 입력 답변 ID, 토큰 수, 지연 시간, 상태와 오류 코드 | 작업 재시도, 장애 분석, 비용·품질 관찰 | Supabase Database |
| 위치 및 날씨 | 사용 시점의 저정밀 현재 위도·경도, 날씨 결과 | 개인화 완료 사용자의 일회성 선제 추천 | 요청 중 메모리, Open-Meteo 요청 |
| 알림 | FCM 토큰, 플랫폼, 활성 상태, 알림 선호, 발송·성공·실패 기록 | 푸시 알림 발송, 사용자 설정 적용, 재시도와 장애 분석 | Supabase Database, Firebase Cloud Messaging |
| 안전 이용 동의 | 정책 종류, 정책 버전, 동의 시각 | 공유 콘텐츠 작성 전 현재 안전 이용 약속 동의 확인, 정책 변경 시 재동의 | Supabase Database |
| 신고·차단·검토 | 신고자·대상 사용자, 신고 대상, 사유, 선택적 상세 설명, 처리 상태, 검토자·검토 시각·결정 이력, 제한된 콘텐츠 스냅샷, 차단 관계, 모더레이션 알림 시도·상태·오류 | UGC·AI 안전 신고 검토와 감사, 운영 알림 재시도, 동일 사용자 재연결 제한 | Supabase Database |
| 기기 로컬 데이터 | 인증 세션, 선제 추천 캐시, 캘린더 표시 설정, 한마디 노출 상태, 미완료 녹음, 위젯 표시 데이터 | 로그인 유지, 성능, 복구, 개인 설정, 위젯 | 보안 저장소, SharedPreferences, 앱 전용 파일, OS 위젯 저장소 |

## 2. 외부 처리자와 전송 범위

| 처리자 | 전송 데이터 | 목적 | 코드상 보호 조치 |
|---|---|---|---|
| Supabase | 위 표의 서버 저장 데이터와 인증 토큰 | 인증, Database, Storage, Realtime, Edge Functions | RLS, 서버 전용 RPC, 비공개 Storage bucket |
| Kakao | 카카오 로그인 요청과 OAuth/OIDC 토큰 | 카카오 계정 로그인 | 앱은 사용자 프로필 API를 별도로 조회하지 않고 토큰을 Supabase 세션 교환에 사용 |
| Apple | Apple 로그인 요청, 인증 코드, ID 토큰 | Apple 계정 로그인과 계정 삭제 시 권한 철회 | nonce 검증 흐름, 삭제 시 재인증 및 Apple 토큰 철회 |
| Google Gemini API | 질문, 답변, 확인된 기억, 최근 질문 문맥 | 기억 후보·피드백·질문·직접 답변·선제 추천 생성 | 이름과 실제 사용자 ID를 `partner_a`, `partner_b`로 치환, 구조화 출력 검증, 민감 주제 차단 |
| Firebase Cloud Messaging | 기기 토큰, 알림 제목·본문·라우팅 데이터 | Android·iOS 푸시 전달 | 사용자 알림 설정, 토큰 비활성화, 전송 결과 기록 |
| Open-Meteo | 소수 둘째 자리로 반올림한 위도·경도 | 현재 날씨와 일몰 맥락 조회 | 저정밀 위치, 짧은 타임아웃, 실패 시 위치 없는 추천으로 전환 |

현재 의존성에는 광고 SDK와 사용자 행동 분석 SDK가 없다.
`profiles.avatar_url` 필드는 스키마와 읽기 모델에만 존재하며 현재 앱에는
이를 입력하거나 업로드하는 흐름이 없다.

## 3. 위치 처리 경계

- Android는 `ACCESS_COARSE_LOCATION`만 요청한다.
- 앱은 `LocationAccuracy.low`로 현재 위치를 한 번 조회한다.
- 위도·경도는 선제 추천 Edge Function 요청 본문으로 전달된다.
- Open-Meteo 전송 전 소수 둘째 자리로 반올림한다.
- 좌표는 Supabase 테이블에 저장하지 않는다.
- 선제 추천 결과와 일일 생성·노출 횟수만 기기 및 서버에 제한적으로 남는다.

## 4. AI 처리 경계

- Gemini에는 실제 사용자 ID와 닉네임 대신 `partner_a`, `partner_b`를 전달한다.
- 질문·답변 본문과 사용자가 확인한 기억은 기능 제공에 필요한 범위에서 전달한다.
- 24개 기초 질문 완료 전에는 확인된 개인화 프로필을 피드백에 사용하지 않는다.
- AI 실행 로그에는 프롬프트 원문을 저장하지 않는다.
- 생성 결과는 기능별 테이블에 저장하며, 실행 로그에는 모델·버전·토큰·지연·오류 상태를 저장한다.
- 민감 카테고리는 별도 동의 전 기억으로 활성화하지 않는다.
- AI 생성 콘텐츠는 앱에서 작은 AI 표시와 신고 진입점을 제공한다.

## 5. 보관과 삭제

| 상황 | Database | Storage | 기기 |
|---|---|---|---|
| 정상 이용 | 계정과 커플 기능 제공 기간 동안 유지 | 비공개 bucket에 유지 | 기능별 캐시·임시 파일 유지 |
| 일반 커플 연결 해제 | 공유 데이터 30일 보관, 읽기 전용 접근과 명시적 재연결 허용 | 30일 보관 | 현재 세션 상태 갱신 |
| 상대방 차단 | 연결 즉시 해제, 공유 데이터 30일 보관하되 양쪽에서 숨김 | 30일 보관 | 차단·연결 상태 갱신 |
| 30일 안에 같은 커플 재연결 | 기존 공유 데이터 복원 | 기존 파일 재사용 | 서버 상태 재동기화 |
| 보관 만료 | 커플 행과 연쇄 참조 데이터 삭제 | 정리 큐를 통해 비동기 삭제 | 다음 동기화 시 제거 |
| 일반 해제 후 즉시 삭제 | 커플 공유 데이터 즉시 삭제 요청 | 정리 큐를 통해 비동기 삭제 | 다음 동기화 시 제거 |
| 계정 삭제 | 사용자가 속한 모든 커플 공유 데이터 삭제 후 Auth 사용자 삭제 | 모든 커플 Storage 객체를 정리 큐로 전달 | AI 캐시, 캘린더 설정, 한마디 상태, 녹음 임시 파일, 위젯 데이터 삭제 |

계정 삭제는 Apple 계정이면 재인증 후 Apple 권한을 먼저 철회한다. 서버의
관계형 데이터 삭제가 성공한 뒤 Storage 파일 삭제가 비동기 정리 큐에서
완료된다.

### 진단·안전 기록의 현재 수명

아래 표는 운영 정책이 아니라 현재 migration의 외래키와 정리 작업을
기준으로 확인한 실제 동작이다.

| 기록 | 현재 자동 파기 | 계정·커플 삭제 시 동작 | 출시 전 필요한 조치 |
|---|---|---|---|
| `ai_processing_jobs`, `ai_runs` | 기간 기반 파기 없음 | 커플 삭제 시 연쇄 삭제 | 진단 보관기간 확정 후 완료·실패 기록의 정기 파기 |
| `push_notification_dispatches` | 기간 기반 파기 없음 | 수신자 계정 삭제 시 연쇄 삭제 | 발송 진단 보관기간 확정 후 정기 파기 |
| `push_notification_deliveries` | 기간 기반 파기 없음 | 수신자 ID만 `null`로 바뀌고 발송 결과는 유지 | 보관기간 확정 후 비식별 발송 결과까지 정기 파기 |
| `safety_reports` | 기간 기반 파기 없음 | 신고자 계정 삭제 시 연쇄 삭제 | 처리 완료 기록의 보관기간 확정 |
| `safety_report_reviews`, `safety_moderation_alerts` | 기간 기반 파기 없음 | 원본 신고 삭제 시 연쇄 삭제 | 원본 신고와 동일한 수명 적용 |
| `user_blocks` | 별도 만료 없음 | 차단 해제 또는 어느 한 계정 삭제 시 제거 | 공개 정책에 유지 조건 명시 |

현재 구조는 계정 삭제 뒤에도 신고 기록을 별도로 보관하지 않는다. 신고
기록을 일정 기간 익명 보관하려면 신고자 외래키를 제거하는 것만으로는
충분하지 않으며, 신고자·대상자·커플·콘텐츠 스냅샷에서 재식별 가능성을
제거하는 별도 익명화 경계가 필요하다.

## 6. 공개 정책 작성 전 확정해야 할 운영 항목

1. 개인정보처리자 또는 사업자 법적 명칭
2. 개인정보 보호 책임자 또는 담당 부서와 연락처
3. 고객지원·개인정보 문의 이메일
4. 서비스 이용 가능 최저 연령과 만 14세 미만 처리 방침
5. 신고 기록과 발송·AI 진단 로그의 구체적인 보관 기간
6. 국외 이전 국가·리전, 이전 시점·방법, 보유 기간을 포함한 각 외부 처리자 계약 정보
7. 웹 계정 삭제 요청의 본인 확인 및 운영 처리 절차
8. 개인정보처리방침·이용약관 시행일
9. 신고 기록을 계정 삭제와 함께 제거할지, 익명화 후 별도 보관할지 여부

## 7. 출시 전 코드·설정 확인 항목

- iOS Runner와 위젯에 각각 `PrivacyInfo.xcprivacy`가 있으며 target
  Resources 포함 여부를 자동 테스트한다. 실제 배포 archive의 통합
  Privacy Report 검증은 Mac에서 남아 있다.
- Android와 iOS 권한 설명은 공개 정책의 실제 이용 목적과 맞춰야 한다.
- 생일 입력은 미래 날짜만 제한하며 만 14세 이상 검증은 없다.
- AI 실행, 푸시 발송과 신고 기록에는 기간 기반 자동 파기 기준이 구현되어
  있지 않다.
- 공개 개인정보처리방침 URL과 외부 계정 삭제 요청 URL이 아직 없다.
- 앱 설정에 개인정보처리방침·이용약관 링크가 구현됐으며, 릴리스 빌드에
  `POLICY_BASE_URL`을 주입해야 한다.
- `ugc-safety-v1` 안전 이용 약속 페이지는 구현됐지만 공개 배포 URL은 아직 없다.
- 신고 모더레이션 알림 큐는 구현됐지만 외부 수신 채널과 전송 함수는 아직 없다.

## 8. 주요 근거 파일

- `apps/mobile/lib/features/auth/data/apple_auth_client.dart`
- `apps/mobile/lib/features/auth/data/kakao_auth_client.dart`
- `apps/mobile/lib/features/auth/data/social_session_repository.dart`
- `apps/mobile/lib/features/profile/data/profile_repository.dart`
- `apps/mobile/lib/features/ai/application/ai_current_location_service.dart`
- `apps/mobile/lib/features/ai/data/ai_proactive_suggestion_repository.dart`
- `apps/mobile/lib/features/notifications/data/push_token_repository.dart`
- `apps/mobile/lib/features/safety/presentation/ugc_safety_policy_screen.dart`
- `apps/mobile/lib/features/account/application/account_local_data_cleanup.dart`
- `apps/mobile/ios/Runner/PrivacyInfo.xcprivacy`
- `apps/mobile/ios/VinscentWidgets/PrivacyInfo.xcprivacy`
- `apps/policy-web/app/safety/page.tsx`
- `docs/release/ios-privacy-declaration.md`
- `supabase/functions/delete-account/`
- `supabase/functions/_shared/push.ts`
- `services/ai-api/src/domain/learning-contract.ts`
- `services/ai-api/src/infrastructure/gemini-structured-generation-client.ts`
- `services/ai-api/src/infrastructure/open-meteo-forecast-client.ts`
- `supabase/migrations/20260720001000_add_ai_consent_memory_and_jobs.sql`
- `supabase/migrations/20260724002000_add_ai_direct_questions.sql`
- `supabase/migrations/20260726000000_add_couple_calendar_events.sql`
- `supabase/migrations/20260729000000_centralize_couple_storage_cleanup.sql`
- `supabase/migrations/20260729002000_add_account_shared_data_deletion.sql`
- `supabase/migrations/20260729004000_add_private_safety_reports.sql`
- `supabase/migrations/20260729005000_add_ugc_safety_report_targets.sql`
- `supabase/migrations/20260729006000_add_user_blocking.sql`
- `supabase/migrations/20260729008000_add_ugc_safety_policy_acceptance.sql`
- `supabase/migrations/20260729009000_enforce_ugc_safety_policy_write_boundary.sql`
- `supabase/migrations/20260729010000_add_safety_moderation_alert_outbox.sql`
- `supabase/migrations/20260729011000_add_safety_report_review_boundary.sql`
