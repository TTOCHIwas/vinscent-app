# GitHub 레퍼런스 프로젝트 조사

조사일: 2026-05-06

## 1. 조사 목적

Flutter 전환 여부를 판단하기 위해 실제 GitHub 공개 레포를 조사했다.

중점 확인 항목:

- Flutter 기반 커플 앱 사례
- Flutter + Supabase 조합 사례
- Riverpod, GoRouter, RLS, 푸시, 구독 사용 사례
- 감성 UI, 메모, 다이어리, 공유 공간, 애니메이션 참고 사례
- AI 기능을 모바일 앱과 분리해 다루는 사례

## 2. 결론

완전히 동일한 레퍼런스, 즉 "Flutter + Supabase + 커플 질문 + AI 개인화 질문" 형태의 공개 프로젝트는 드물다.

다만 아래 조합은 실제 레포에서 반복적으로 확인된다.

- Flutter + Supabase
- Flutter + Riverpod
- Flutter + 커플 앱
- Flutter + 감성 UI/공유 공간
- Supabase RLS 기반 커플/파트너 데이터 보호
- RevenueCat 기반 모바일 구독
- AI 기능을 별도 API 또는 Edge Function으로 처리

따라서 우리 프로젝트의 Flutter 전환은 레퍼런스 관점에서도 충분히 타당하다.

## 3. 직접 참고 가치가 높은 레퍼런스

### 3.1 Twain

- URL: https://github.com/judahben149/twain
- 설명: 커플이 작은 순간을 공유하는 Flutter 앱
- 스택: Flutter, Supabase, RevenueCat, Push notifications
- 주요 기능:
  - sticky notes
  - shared board
  - wallpaper sync
  - location sharing
  - notifications
  - subscription

우리에게 참고할 점:

- 커플 메모와 공유 공간 UX
- Supabase 기반 커플 데이터 저장
- RevenueCat 기반 구독 모델
- "시끄러운 채팅 앱이 아니라 작고 의미 있는 상호작용"이라는 제품 방향

주의할 점:

- 질문/답변 앱은 아니므로 daily question 플로우는 별도 설계가 필요하다.
- 라이선스가 non-commercial 성격이므로 코드 복사는 피하고 구조만 참고한다.

### 3.2 TwoWallet

- URL: https://github.com/NishanBhuje1/twowallet
- 설명: 커플 공동 재무 관리 앱
- 스택: Flutter, Riverpod, GoRouter, Supabase, Supabase Edge Functions, RevenueCat, PostHog, Claude API
- 주요 기능:
  - 커플 연결 기반 데이터
  - shared finance
  - weekly Money Date
  - AI 기반 대화 프롬프트
  - RLS
  - 구독

우리에게 참고할 점:

- Flutter + Riverpod + GoRouter + Supabase 조합
- Supabase RLS를 파트너 데이터에 적용하는 방식
- AI가 커플 대화를 돕는 기능 경계
- RevenueCat, analytics, Edge Functions 등 실서비스 준비 요소

특히 참고할 점:

- README에서 RLS 정책은 여러 사용자 컨텍스트로 테스트해야 한다고 강조한다. 우리 앱도 "본인 답변은 볼 수 있지만 상대 답변은 둘 다 답변 후 공개" 정책을 DB 레벨에서 반드시 테스트해야 한다.

### 3.3 HomeSync

- URL: https://github.com/homesync-app/homesync-app
- 설명: 커플/가구용 Flutter + Supabase 앱
- 스택: Flutter, Supabase, Riverpod, Firebase Messaging
- 구조:
  - `flutter_client`
  - `supabase`
  - `homesync_admin`
  - `database`
  - `docs`
- 주요 기능:
  - auth
  - household/couple-like group
  - tasks
  - expenses
  - savings
  - shopping
  - dashboard
  - rewards
  - notifications

우리에게 참고할 점:

- feature-first Flutter 폴더 구조
- Supabase migration과 Flutter client를 같은 저장소에서 관리하는 방식
- 디자인 문서와 Flutter client가 함께 존재하는 운영 방식
- "감성적이지만 실용적인 공유 공간" 설계

주의할 점:

- 커플 질문 앱이라기보다는 household productivity 앱에 가깝다.
- 기능 범위가 넓어서 MVP에는 과하다.

### 3.4 Amora

- URL: https://github.com/AbdulRahmanMudasser/flutter-amora-v2
- 설명: 개인용 romantic couple app
- 스택: Flutter, Riverpod, Hive, flutter_secure_storage, Lottie
- 주요 기능:
  - home
  - partner profile
  - memories
  - rich writing
  - calendar/reminders
  - local storage

우리에게 참고할 점:

- 감성적인 커플 앱 톤
- 메모리/다이어리 작성 기능
- Lottie 기반 감성 요소
- 로컬 저장 중심 구조

주의할 점:

- Supabase 기반 커플 동기화보다는 개인/로컬 앱에 가깝다.
- 보안/커플 공개 조건/RLS 참고 자료로는 부족하다.

### 3.5 OOUZOO

- URL: https://github.com/NS-DDC/oouzoo
- 설명: 로컬 퍼스트 커플 우주 앱
- 스택: Flutter, Riverpod, SQLite, Firebase Realtime DB relay, FCM
- 주요 기능:
  - local-first diary
  - mood emoji
  - D-Day
  - planet/pet growth
  - backup/restore
  - FCM

우리에게 참고할 점:

- 커플 앱의 감성 세계관 설계
- 로컬 퍼스트 데이터 전략
- 감정 기록 UI
- D-Day
- 에셋 기반 감성 시스템

주의할 점:

- 우리는 반려몽/펫 성장 기능은 제외한다.
- 서버 없는 구조는 우리 AI/Supabase 중심 아키텍처와 다르다.

### 3.6 Love Connect

- URL: https://github.com/amarhumayunx/Love-Connect
- 설명: 커플 데이트 계획, 추억 공유, 감성 UI 앱
- 스택: Flutter, GetX, Firebase, shared_preferences
- 주요 기능:
  - date planning
  - date idea library
  - surprise wheel
  - scratch cards
  - shared journal
  - reminders

우리에게 참고할 점:

- 데이트 아이디어와 감성 인터랙션
- scratch card, wheel 같은 귀여운 마이크로 인터랙션
- shared journal UI
- 기념일/리마인더 경험

주의할 점:

- GetX/Firebase 기반이라 우리 기본 스택과 다르다.
- 구조보다 UX 아이디어 참고용으로 보는 것이 좋다.

## 4. AI/백엔드 참고 레퍼런스

### 4.1 PocketLLM

- URL: https://github.com/PocketLLM/PocketLLM
- 설명: Flutter 앱 + FastAPI 백엔드 기반 AI 챗 앱
- 스택: Flutter, FastAPI, Supabase
- 주요 기능:
  - provider catalog
  - chat history
  - secure key storage
  - backend REST API
  - Supabase storage of user data

우리에게 참고할 점:

- 모바일 앱에서 AI provider를 직접 호출하지 않고 백엔드 API를 거치는 구조
- Flutter client와 AI backend를 함께 관리하는 방식
- AI 기능 로그/보안/에러 처리 방향

주의할 점:

- 관계/커플 앱은 아니다.
- README상 개발이 일시 중단되었다고 명시되어 있으므로 유지보수 참고에는 한계가 있다.

### 4.2 Supabase Flutter

- URL: https://github.com/supabase/supabase-flutter
- 설명: Supabase 공식 Flutter 클라이언트
- 참고할 점:
  - Supabase Flutter 공식 사용 방식
  - Auth, PostgREST, Realtime, Storage 연동
  - Flutter 앱에서 Supabase를 쓰는 기본 패턴

## 5. 기능 참고용 Expo 레퍼런스

### 5.1 gilyoungCoder/sumone

- URL: https://github.com/gilyoungCoder/sumone
- 설명: 썸원에서 영감을 받은 커플 앱
- 스택: React Native, Expo, Supabase, Zustand, NativeWind
- 주요 기능:
  - email auth
  - invite code based couple connection
  - D-day
  - daily questions
  - mood picker
  - profile management

우리에게 참고할 점:

- 기술 스택은 채택하지 않는다.
- 커플 코드 연결, daily question, mood picker, Supabase schema는 기능 참고 가치가 높다.

## 6. 레퍼런스 기반 기술 판단

### 6.1 유지할 결정

- 모바일 앱은 Flutter로 간다.
- Supabase를 초기 백엔드로 사용한다.
- Riverpod을 기본 상태관리로 사용한다.
- GoRouter를 라우팅 후보로 둔다.
- 푸시는 FCM 기반으로 설계한다.
- AI 기능은 모바일 앱에서 직접 호출하지 않고 서버를 거친다.

### 6.2 추가로 강화할 결정

- RLS 테스트를 초기부터 작성한다.
- 커플 연결, 답변 공개 조건은 클라이언트 UI가 아니라 DB/RPC/API에서 강제한다.
- 구독은 직접 구현보다 RevenueCat을 우선 검토한다.
- 감성 UI는 Lottie/Rive/Flutter animation을 초반 UI 스파이크에서 검증한다.
- 관리자 웹은 MVP에서 제외하되, Supabase Dashboard로 운영 가능한 로그 테이블을 미리 설계한다.

### 6.3 참고 우선순위

1. Twain: 커플 메모, 공유 공간, Supabase, 구독
2. TwoWallet: Flutter + Riverpod + GoRouter + Supabase + AI 대화 프롬프트
3. HomeSync: feature-first 구조, Supabase migration, 디자인 문서
4. Amora: 감성 커플 앱, 메모리 작성, Lottie
5. Love Connect: 귀여운 인터랙션, shared journal, 데이트 아이디어
6. OOUZOO: 감정 기록, D-Day, 감성 세계관
7. gilyoungCoder/sumone: daily question 기능 구조
8. PocketLLM: AI backend 분리 구조

## 7. 최종 판단

GitHub 레퍼런스를 보면 Flutter 커플 앱 사례는 충분히 존재한다. 다만 대부분은 소규모 개인 프로젝트이며, 우리 앱처럼 AI 개인화 질문까지 포함한 성숙한 오픈소스 레퍼런스는 드물다.

따라서 하나의 레포를 그대로 따라가기보다는 다음처럼 조합해 참고한다.

- 커플 UX: Twain, Amora, Love Connect, OOUZOO
- Supabase/RLS/구독: TwoWallet, Twain, HomeSync
- daily question: gilyoungCoder/sumone
- AI API 분리: PocketLLM
- 공식 Supabase Flutter 사용법: supabase/supabase-flutter

이 조합을 기준으로 보면, 현재 프로젝트는 Flutter + Supabase + 별도 AI API 방향으로 진행하는 것이 합리적이다.
