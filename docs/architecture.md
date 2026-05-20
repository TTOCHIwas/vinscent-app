# 아키텍처 설계

작성일: 2026-05-06

## 1. 기술 결정

모바일 앱의 기준 스택을 Flutter로 변경한다.

결정 이유:

- 사용자용 웹 서비스는 만들지 않는다.
- 제품의 중심은 Android/iOS 모바일 앱이다.
- 감성 UI, 마이크로 인터랙션, 애니메이션이 제품 경험의 큰 비중을 차지할 가능성이 높다.
- 개발자가 Flutter를 배운 경험이 있다.
- Flutter는 자체 렌더링 기반이라 Android/iOS에서 일관된 감성 UI를 만들기 좋다.

주의할 점:

- Windows에서는 iOS Simulator를 사용할 수 없다.
- Flutter도 iOS 빌드와 iOS 실기기 디버깅에는 macOS/Xcode 환경이 필요하다.
- 따라서 MVP 초기 개발은 Android 기준으로 진행하고, iOS 검증을 위해 iPhone과 원격 Mac 또는 Mac mini를 확보하는 방향으로 간다.

## 2. 아키텍처 방향

MVP는 빠르게 검증할 수 있어야 하며, 동시에 커플 답변과 AI 메모리처럼 민감한 데이터를 안전하게 다룰 수 있어야 한다.

초기 아키텍처는 다음 방향으로 설계한다.

- 모바일 앱은 Flutter 기반으로 Android와 iOS를 지원한다.
- 사용자용 웹 서비스는 만들지 않는다.
- 기본 인증, DB, 파일 저장, RLS는 Supabase를 활용한다.
- AI 질문 생성, AI 메모리, 민감한 서버 정책은 별도 AI API 서버에서 처리한다.
- 관리자 웹은 MVP에서 제외한다. 초기 운영은 Supabase Dashboard와 SQL/RPC 관리로 시작한다.
- 관리자 도구가 필요해지는 시점에 별도 internal admin을 추가한다.

## 3. 전체 구성

```text
Flutter Mobile App
  Android / iOS
  Riverpod
  GoRouter
  Supabase Flutter
        |
        | Supabase anon client
        v
Supabase
  Auth
  Postgres
  Row Level Security
  Storage
  Realtime
        ^
        |
        | service role, server-side only
        |
AI API Server
  Node.js / Fastify / TypeScript
  Supabase JWT 검증
  LLM 호출
  AI 메모리 생성
  질문 생성
  안전 필터링
```

## 4. 기술 스택

### 4.1 모바일 앱

- Framework: Flutter
- Language: Dart
- State management: Riverpod
- Routing: GoRouter
- Backend client: supabase_flutter
- Secure local storage: flutter_secure_storage
- Model generation: freezed, json_serializable
- Environment config: flutter_dotenv 또는 dart-define
- Push notification: firebase_messaging, flutter_local_notifications
- Animation: Flutter animation APIs, Rive, Lottie
- Design system: custom theme, reusable design tokens

MVP에서는 Riverpod, GoRouter, Supabase Flutter를 기본 축으로 사용한다. Freezed와 code generation은 모델이 늘어나는 시점부터 본격적으로 사용한다.

### 4.2 백엔드

- Primary backend: Supabase
- Auth: Supabase Auth
- Database: Supabase Postgres
- Database policy: Row Level Security
- Realtime: Supabase Realtime
- Storage: Supabase Storage
- Server-side DB logic: Supabase RPC 또는 Edge Functions

중요 정책은 클라이언트 UI가 아니라 DB policy, RPC, AI API 서버에서 강제한다.

### 4.3 AI API 서버

- Runtime: Node.js
- Framework: Fastify
- Language: TypeScript
- Auth: Supabase JWT 검증
- DB access: Supabase service role key, 서버에서만 사용
- LLM: OpenAI API 또는 추후 교체 가능한 provider adapter
- Background jobs: 초기에는 cron 기반, 필요 시 BullMQ + Redis

AI API 서버는 처음부터 크게 만들지 않는다. MVP에서는 다음만 담당한다.

- 요청 사용자의 Supabase JWT 검증
- 사용자가 해당 커플의 멤버인지 확인
- 공개 완료된 답변 조회
- AI 질문 생성
- 안전 필터링
- 생성 로그 저장

### 4.4 관리자 도구

MVP에서는 별도 관리자 웹을 만들지 않는다.

초기 운영:

- Supabase Dashboard
- SQL editor
- migration
- seed data
- 로그 테이블 조회

추후 다음 조건이 생기면 internal admin을 추가한다.

- 운영자가 질문을 직접 관리해야 한다.
- 신고/문의 처리가 필요하다.
- AI 생성 질문 로그를 비개발자가 확인해야 한다.
- 결제/구독 상태 조회가 필요하다.

## 5. 권장 저장소 구조

```text
apps/
  mobile/
    lib/
      app/
      core/
      features/
        auth/
        profile/
        couple/
        home/
        questions/
        answers/
        archive/
        memos/
        emotions/
      shared/
    assets/
      images/
      animations/
      icons/
    test/

services/
  ai-api/
    src/
      modules/
        auth/
        couples/
        questions/
        ai/
        notifications/
      server.ts

supabase/
  migrations/
  seed/
  functions/

docs/
```

현재 저장소의 `apps/mobile`은 Flutter 프로젝트로 생성되어 있다. 문서 기준의 최종 모바일 스택은 Flutter다.

## 6. 주요 도메인 모델

### 6.1 profiles

Supabase Auth의 `auth.users`를 기준으로 하며, 앱 전용 사용자 정보는 `profiles`에 저장한다.

주요 필드:

- id
- display_name
- birth_date
- avatar_url
- created_at
- updated_at

### 6.2 couples

커플 연결 단위다.

주요 필드:

- id
- invite_code
- user_a_id
- user_b_id
- relationship_start_date
- timezone
- status
- connected_at
- disconnected_at
- created_at
- updated_at

정책:

- 한 사용자는 활성 커플을 하나만 가질 수 있다.
- 커플 연결은 초대 코드 기반으로 진행한다.
- 연결 해제 후 데이터 보관 정책은 별도 정책 문서에서 확정한다.

### 6.3 questions

질문 원본 또는 AI 생성 질문을 저장한다.

주요 필드:

- id
- source
  - curated
  - ai
- text
- category
- mood
- sensitivity_level
- created_by
- created_at

### 6.4 daily_questions

커플에게 특정 날짜에 배정된 질문이다.

주요 필드:

- id
- couple_id
- question_id
- assigned_date
- status
  - pending
  - answered_by_one
  - completed
- created_at

제약:

- `couple_id + assigned_date`는 unique다.
- 하루에 한 커플에게 하나의 질문만 배정한다.

### 6.5 answers

각 사용자의 질문 답변이다.

주요 필드:

- id
- daily_question_id
- couple_id
- user_id
- body
- emotion
- submitted_at
- edited_at
- ai_memory_excluded
- created_at

정책:

- 본인은 자신의 답변을 작성할 수 있다.
- 상대 답변은 두 사람 모두 답변한 뒤에만 볼 수 있다.
- AI 메모리는 공개 완료된 답변만 사용한다.

### 6.6 answer_comments

공개된 답변에 남기는 댓글이다.

주요 필드:

- id
- answer_id
- couple_id
- user_id
- body
- created_at

### 6.7 memos

커플 홈에 남기는 짧은 메모다.

주요 필드:

- id
- couple_id
- author_id
- body
- color
- sticker_key
- pinned_until
- created_at

### 6.8 reactions

상대 답변에 남기는 간단한 리액션이다.

주요 필드:

- id
- answer_id
- couple_id
- user_id
- type
- created_at

### 6.9 ai_memories

커플별 AI 장기 메모리다.

주요 필드:

- id
- couple_id
- summary
- topics
- preferences
- avoid_topics
- relationship_events
- last_built_at
- created_at
- updated_at

정책:

- 모바일 앱에서 직접 수정하지 않는다.
- AI API 서버만 생성 및 갱신한다.
- 사용자가 특정 답변을 AI 기억 제외 처리하면 다음 메모리 재생성 때 반영한다.

### 6.10 ai_question_logs

AI 질문 생성 기록이다.

주요 필드:

- id
- couple_id
- generated_question_id
- prompt_version
- input_answer_ids
- safety_status
- user_feedback
- created_at

목적:

- 질문 품질 개선
- 안전 필터 검토
- 운영자 디버깅

### 6.11 device_tokens

푸시 알림 발송을 위한 기기 토큰이다.

주요 필드:

- id
- user_id
- platform
- fcm_token
- apns_token
- device_id
- enabled
- updated_at

### 6.12 notifications

앱 내 알림 및 푸시 발송 로그다.

주요 필드:

- id
- user_id
- couple_id
- type
- title
- body
- delivery_status
- created_at
- sent_at

## 7. 핵심 플로우

### 7.1 회원가입 및 프로필 생성

1. 사용자가 소셜 로그인한다.
2. Supabase Auth에 사용자가 생성된다.
3. `profiles` 레코드가 생성된다.
4. 사용자가 닉네임, 생일, 연애 시작일을 입력한다.
5. 프로필 저장 후 커플 연결 화면으로 이동한다.

### 7.2 커플 연결

1. 사용자 A가 초대 코드를 생성한다.
2. `couples` 레코드가 `user_a_id`만 채워진 상태로 생성된다.
3. 사용자 B가 초대 코드를 입력한다.
4. 서버는 초대 코드 유효성, 중복 연결 여부를 검사한다.
5. `user_b_id`를 채우고 커플 상태를 active로 변경한다.
6. 두 사용자에게 연결 완료 알림을 보낸다.

권장 구현:

- 초대 코드 조회 및 연결은 Supabase RPC 또는 Edge Function으로 처리한다.
- 단순 클라이언트 업데이트로 처리하지 않는다.

### 7.3 오늘의 질문 배정

1. 매일 지정된 시간 또는 사용자가 앱을 열 때 오늘 질문이 있는지 확인한다.
2. 오늘 질문이 없으면 질문을 생성하거나 기존 질문을 배정한다.
3. AI 기능이 활성화된 커플은 AI API가 질문을 생성한다.
4. AI 기능이 비활성화됐거나 실패하면 curated question fallback을 사용한다.
5. `daily_questions`에 배정 결과를 저장한다.

MVP에서는 앱 진입 시 lazy assignment 방식을 우선 사용한다.

### 7.4 답변 작성 및 공개

1. 사용자 A가 오늘 질문에 답변한다.
2. `answers`에 답변을 저장한다.
3. 사용자 B가 아직 답변하지 않았다면 상대 답변은 잠김 상태로 유지한다.
4. 사용자 B도 답변하면 `daily_questions.status`를 completed로 변경한다.
5. 두 사용자 모두 서로의 답변을 볼 수 있다.
6. 상대에게 답변 공개 알림을 보낸다.

중요 정책:

- 한쪽 답변이 공개 전 AI 질문이나 요약에 의해 유추되면 안 된다.
- 공개 전 답변은 작성자 본인과 서버 정책만 접근할 수 있어야 한다.

### 7.5 AI 질문 생성

1. 모바일 앱 또는 스케줄러가 AI API에 다음 질문 생성을 요청한다.
2. AI API는 Supabase JWT를 검증한다.
3. 서버는 요청 사용자가 해당 커플의 멤버인지 확인한다.
4. 공개 완료된 최근 답변과 `ai_memories`를 조회한다.
5. 피하고 싶은 주제, 민감도, 최근 질문 중복 여부를 반영한다.
6. LLM으로 후보 질문을 생성한다.
7. 안전 필터를 통과시킨다.
8. 통과한 질문을 `questions`와 `daily_questions`에 저장한다.
9. 생성 로그를 `ai_question_logs`에 저장한다.

### 7.6 AI 메모리 갱신

1. 커플의 답변이 일정 개수 이상 쌓이거나 하루 1회 배치로 실행한다.
2. 공개 완료된 답변만 사용한다.
3. `ai_memory_excluded = true`인 답변은 제외한다.
4. 커플 관심사, 반복 주제, 최근 이벤트, 피해야 할 주제를 요약한다.
5. `ai_memories`를 갱신한다.

## 8. 보안 및 권한

### 8.1 Row Level Security 원칙

- 모든 사용자 데이터 테이블은 RLS를 활성화한다.
- 사용자는 본인이 속한 커플 데이터만 읽을 수 있다.
- 답변은 공개 조건을 만족해야 상대가 읽을 수 있다.
- 관리자 권한은 일반 클라이언트 권한과 분리한다.
- service role key는 모바일 앱에 절대 노출하지 않는다.

### 8.2 답변 공개 정책

답변 조회 조건:

- 본인 답변은 항상 조회 가능하다.
- 상대 답변은 같은 `daily_question_id`에 두 사람의 답변이 모두 존재할 때만 조회 가능하다.

이 정책은 클라이언트 UI가 아니라 DB policy, view, RPC 또는 서버 API에서 강제해야 한다.

### 8.3 AI 데이터 정책

- AI는 공개 완료된 커플 답변만 사용한다.
- 답변 작성 중인 데이터는 AI에 전달하지 않는다.
- 사용자가 AI 기억 제외 처리한 답변은 AI 메모리와 질문 생성에 사용하지 않는다.
- AI 생성 질문 로그에는 원문 전체를 과도하게 저장하지 않는다.
- 프롬프트와 응답 로그는 운영에 필요한 최소 범위로 저장한다.

## 9. 푸시 알림 구조

초기에는 Firebase Cloud Messaging을 사용한다.

Android:

- FCM token 기반 발송

iOS:

- FCM을 통해 APNs로 발송하거나, 추후 APNs 직접 연동을 고려한다.
- iOS 푸시 테스트와 인증서/프로비저닝 설정에는 Apple Developer Program과 macOS/Xcode 환경이 필요하다.

주요 알림:

- 오늘의 질문 도착
- 상대 답변 완료
- 미답변 리마인드
- 메모 도착
- 댓글 도착

발송 방식:

- 즉시 알림은 클라이언트 이벤트 후 서버 함수 또는 AI API 서버에서 발송한다.
- 예약 알림은 Supabase scheduled job 또는 별도 cron worker에서 발송한다.

## 10. 배포 및 개발 환경

### 10.1 Android 개발

- Windows에서 Android Studio와 Android SDK를 사용한다.
- Android Emulator 또는 Android 실기기로 개발한다.
- MVP 초기 개발은 Android 기준으로 진행한다.

### 10.2 iOS 개발

- Windows에서는 iOS Simulator를 사용할 수 없다.
- Flutter iOS 빌드와 실기기 디버깅에는 macOS/Xcode가 필요하다.
- iOS 검증을 위해 다음 중 하나가 필요하다.
  - 원격 Mac
  - 중고 Mac mini
  - iOS QA 외주 또는 테스터
- iPhone 실기기는 최종 UI/사용성 확인에 필요하다.

### 10.3 배포

Android:

- Google Play Developer 계정 필요
- 로컬 또는 CI에서 Android release build 가능

iOS:

- Apple Developer Program 필요
- macOS/Xcode 또는 macOS CI 필요
- TestFlight 기반 검증 필요

## 11. 단계별 구현 전략

### Phase 1: Flutter 앱 골격

- Flutter 프로젝트 생성
- 앱 테마 및 디자인 토큰
- Riverpod 설정
- GoRouter 설정
- Supabase 연결
- 기본 화면 구조

### Phase 2: 기본 앱 성립

- 로그인
- 프로필
- 커플 코드 연결
- 홈 화면
- 오늘의 질문
- 답변 작성
- 답변 공개
- 답변 아카이브

### Phase 3: 커플 경험 강화

- 메모
- 리액션
- 댓글
- 감정 기록
- 즐겨찾기
- 기본 푸시 알림

### Phase 4: AI MVP

- AI API 서버 생성
- Supabase JWT 검증
- 공개 답변 기반 질문 생성
- 질문 안전 필터
- AI 질문 피드백
- curated question fallback

### Phase 5: 운영 및 수익화 준비

- 운영용 SQL/view 정리
- AI 생성 로그 조회
- 신고 및 문의 처리 방식
- 구독 권한 모델
- 월간 리포트
- 추가 테마 및 스티커

## 12. 주요 아키텍처 결정

### 12.1 Flutter를 사용한다

이유:

- 사용자용 웹 서비스가 없다.
- 모바일 앱의 감성 UI와 애니메이션 품질이 중요하다.
- Android/iOS에서 일관된 화면을 만들기 좋다.
- 개발자가 Flutter 경험이 있다.

주의:

- iOS 개발 환경 제약은 Expo보다 크다.
- iOS 검증을 위해 Mac 또는 원격 Mac이 필요하다.

### 12.2 Supabase를 초기 백엔드로 사용한다

이유:

- 인증, Postgres, RLS, Storage, Realtime을 빠르게 구성할 수 있다.
- 커플 앱 MVP의 기본 CRUD를 빠르게 검증할 수 있다.
- Flutter용 공식 클라이언트가 있다.

주의:

- 복잡한 비즈니스 로직을 클라이언트에 흩뿌리지 않는다.
- 커플 연결, 답변 공개, AI 메모리 등 중요한 정책은 RPC, Edge Function, AI API에서 강제한다.

### 12.3 AI API는 Supabase와 분리한다

이유:

- LLM API key를 안전하게 보호해야 한다.
- 프롬프트 버전 관리, 안전 필터, 로그, 재시도 처리가 필요하다.
- 향후 모델 교체와 비용 제어가 필요하다.

## 13. GitHub 레퍼런스 검토

### 13.1 Flutter 레퍼런스

#### judahben149/twain

- URL: https://github.com/judahben149/twain
- 설명: 커플용 wallpaper sync, sticky notes, shared board, location sharing 앱
- 스택: Flutter, Supabase, RevenueCat, Push notifications
- 기능: sticky notes, shared board, 위치 공유, 알림, 구독

시사점:

- 커플 메모, 공유 공간, 구독 모델 참고에 좋다.
- Flutter + Supabase 조합은 커플 앱에도 현실적인 선택지다.

#### amarhumayunx/Love-Connect

- URL: https://github.com/amarhumayunx/Love-Connect
- 설명: 커플용 데이트 계획, 추억 공유, 연결 경험 앱
- 스택: Flutter, Firebase

시사점:

- 감성적인 커플 앱 UI와 Flutter 앱 구조 참고에 좋다.
- 백엔드는 Firebase지만, 앱 레이어 패턴은 참고 가능하다.

### 13.2 AI 관계 앱 레퍼런스

#### TomoyamiP/purecomm

- URL: https://github.com/TomoyamiP/purecomm
- 설명: 커플 커뮤니케이션 웹앱
- 스택: Ruby on Rails, PostgreSQL, OpenAI API
- 기능: mood check-in, love-language insights, AI coach

시사점:

- 모바일 앱 구조 참고보다는 AI 기능 경계와 톤 설계 참고용이다.

### 13.3 Expo 레퍼런스

#### gilyoungCoder/sumone

- URL: https://github.com/gilyoungCoder/sumone
- 설명: 썸원에서 영감을 받은 미국 시장용 커플 앱
- 스택: React Native, Expo, Supabase, Zustand, NativeWind
- 기능: 이메일 인증, 커플 초대 코드, 디데이, daily questions, mood picker, 프로필

시사점:

- 기능 모델은 우리 MVP와 매우 유사하다.
- 기술 스택은 Flutter로 변경하지만, 커플 코드와 daily question 구조는 참고 가치가 있다.

#### kabirjaipal/duogram

- URL: https://github.com/kabirjaipal/duogram
- 설명: 커플 연결, 채팅, 관계 마일스톤 앱
- 스택: React Native, Expo, Expo Router, Appwrite, TypeScript

시사점:

- 커플 연결 UX와 홈 대시보드 구조 참고에 좋다.
- 기술 스택은 직접 채택하지 않는다.

### 13.4 최종 판단

사용자용 웹 서비스가 없고, 감성 UI/애니메이션이 제품의 중요한 차별점이라면 Flutter가 더 적합하다.

> 최종 모바일 스택은 Flutter로 변경한다. 백엔드는 Supabase 중심으로 유지하고, AI 기능은 별도 API 서버에서 처리한다. MVP 초기 개발은 Android 기준으로 진행하되, iOS 검증을 위해 iPhone과 Mac 또는 원격 Mac 확보를 전제로 한다.

## 14. 추후 확장 고려

- AI API를 queue 기반 비동기 구조로 전환
- vector database 도입
- 답변 원문 암호화 강화
- 커플별 타임존 스케줄러
- RevenueCat 기반 구독 관리
- 앱 위젯
- 사진 첨부 및 Storage 정책
- 다국어 질문 생성
- Rive 기반 감성 애니메이션 시스템
