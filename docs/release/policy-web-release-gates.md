# 단짠 정책 웹 출시 게이트

이 문서는 공개 개인정보처리방침, 이용약관, 계정 삭제 안내와 고객지원
안내를 작성하고 배포하기 전에 코드와 운영 조건이 충족해야 하는 기준을
정리한다. 공개 문서는 실제 처리 상태와 일치해야 하며, 미확정 정보를
추정해서 기재하지 않는다.

검토 기준일은 2026년 7월 30일이다.

## 1. 공식 기준

### 개인정보처리방침

- 「개인정보 보호법」 제30조와 같은 법 시행령 제31조에 따라 처리 목적,
  보유기간, 제3자 제공, 파기, 정보주체의 권리행사, 개인정보 보호책임자,
  처리 항목, 국외 이전, 안전성 확보조치 등을 실제 처리 현황에 맞게
  공개해야 한다.
- 개인정보보호위원회의 「개인정보 처리방침 작성지침(2026.4. 개정)」을
  문서 구조와 표현의 기준으로 사용한다.
- Apple App Review Guideline 5.1.1은 수집 데이터, 수집 방법, 모든 이용
  목적, 외부 처리자, 보관·삭제, 동의 철회와 삭제 요청 방법을 명확하게
  공개하도록 요구한다.

### 계정 삭제

- Apple은 계정 생성 앱이 앱 안에서 전체 계정과 관련 데이터를 삭제할 수
  있는 경로를 제공하도록 요구한다.
- Google Play는 앱 내부 삭제 경로와 별도로, 앱을 설치하지 않은 사용자도
  계정 및 관련 데이터 삭제를 요청할 수 있는 공개 웹 경로를 요구한다.
- 외부 삭제 페이지는 단짠 또는 스토어 개발자명을 명시하고 삭제 요청
  방법을 눈에 띄게 안내해야 한다.
- 「개인정보 보호법」 제36조에 따른 개인정보 정정·삭제 요구는 지체 없이
  조사하고 필요한 조치를 해야 하며, 시행령 제43조에 따라 요구받은 날부터
  10일 이내에 결과를 알려야 한다.
- 외부 계정 삭제가 수동으로 처리되더라도 본인 확인 방법, 예상 처리 기간,
  완료 통지 방법을 공개하고 실제 운영 절차와 일치시켜야 한다.

### 생성형 AI

- 운영 AI 공급자는 Cloudflare Workers AI이고 기본 모델은
  `@cf/qwen/qwen3-30b-a3b-fp8`이다.
- Cloudflare는 Workers AI 고객 콘텐츠를 명시적인 동의 없이 AI 모델
  학습이나 Cloudflare·제3자 서비스 개선에 사용하지 않는다고 밝힌다.
- 입력과 생성 결과는 별도 R2, KV, Durable Objects 또는 Vectorize 저장소에
  연결하지 않으며, 단짠의 검증된 결과만 Supabase 기능별 테이블에 저장한다.
- 개인정보보호위원회의 2026년 작성지침은 AI의 의도된 용례, 이용자가
  입력한 정보와 생성 결과의 수집·저장 여부, 모델 학습 활용 여부,
  학습 활용 거부 절차, 부적절한 결과의 신고·이의제기 경로를 실제 처리
  현황에 맞게 공개하도록 안내한다.

### 날씨 API

- Open-Meteo는 일반 무료 API를 비상업적 이용 대상으로 제공한다.
- 상업적 서비스는 구독과 API 키가 적용되는 고객용 엔드포인트를 사용해야
  한다.

## 2. 현재 코드에서 확인된 상태

| 항목 | 현재 상태 | 근거 |
|---|---|---|
| AI 처리자 안내 | 동의 화면에 Cloudflare Workers AI와 질문·답변 분석 목적이 표시됨 | `apps/mobile/lib/features/ai/presentation/widgets/ai_learning_dashboard_view.dart` |
| 서비스 이용 연령 | 앱과 Database가 서울 기준 날짜로 만 14세 이상을 검증함 | `apps/mobile/lib/core/date/app_age_policy.dart`, `20260730000000_enforce_profile_minimum_age.sql` |
| AI 공급자 | Cloudflare Workers AI와 Qwen3 비사고 모드로 운영 경로가 구성됨 | Edge Function 공통 AI 조립 모듈과 런타임 매니페스트 |
| 날씨 엔드포인트 | 무료 일반 엔드포인트 `https://api.open-meteo.com/v1/forecast` 사용 | `services/ai-api/src/infrastructure/open-meteo-forecast-client.ts` |
| 앱 내부 계정 삭제 | 설정에서 계정과 관련 공유 데이터를 삭제하는 흐름이 구현됨 | 계정 삭제 기능 및 서버 삭제 함수 |
| 외부 계정 삭제 | 공개 요청 URL이 없음 | 정책 웹 미배포 |
| 앱 내부 정책 링크 | 설정에 개인정보처리방침·이용약관 링크가 구현됐으며 공개 기본 URL 주입이 필요함 | `POLICY_BASE_URL` |
| UGC 안전 약속 | `ugc-safety-v1` 동의 화면, 서버 쓰기 경계와 `/safety` 문서가 구현됨 | 모바일·Database·정책 웹 |
| UGC 게시 전 필터 | 공유 텍스트·이미지·오디오를 게시 전에 검사하는 경계가 없음 | 공급자·검사 범위·실패 정책 결정 및 구현 필요 |
| 신고 검토 기반 | 내구성 있는 모더레이션 알림 큐, 최소 메타데이터 전송 워커와 검토자·결정 감사 경계가 구현됨 | 실제 HTTPS 수신 채널·담당자·목표 시간 결정 및 통합 검증 필요 |
| 개인정보 저장 위치 | Supabase 프로젝트의 주 데이터 리전은 `ap-northeast-1`임 | 연결된 프로젝트 환경 |
| 운영자 정보 | 법적 운영자명, 공개 문의 이메일, 시행일이 저장소에 없음 | 운영자 확인 필요 |
| 진단·신고 보관기간 | 공개 가능한 구체적 보관기간이 확정되지 않음 | 운영자 결정 및 정리 정책 필요 |
| 신고 기록의 계정 삭제 동작 | `safety_reports.reporter_user_id`가 `auth.users` 삭제 시 연쇄 삭제되므로 신고자의 계정 삭제와 함께 신고·검토·알림 기록도 제거됨 | `20260729004000_add_private_safety_reports.sql` |
| 외부 삭제 접수 | 정책 웹에 초안만 있고 본인 확인 방법, 공개 접수 주소, 처리 기한과 완료 통지 절차가 없음 | `apps/policy-web/app/account-deletion/page.tsx` |
| 고객지원 웹 경로 | `/support` 초안은 구현됐지만 실제 공개 이메일과 응답 기준이 없음 | `apps/policy-web/app/support/page.tsx` |

`ap-northeast-1`은 Supabase와 AWS가 표기하는 일본 도쿄 리전이다.

## 3. 배포 전에 필요한 운영 결정

다음 항목은 운영자가 확정하기 전까지 공개 정책을 배포하지 않는다.

1. 개인정보처리자에 표시할 정확한 법적 이름
2. 고객지원 및 개인정보 문의에 사용할 공개 이메일
3. 정책 시행일
4. 만 14세 이상 이용 기준을 공개 약관과 개인정보처리방침에 반영할 문구
5. Open-Meteo 상업용 구독 또는 다른 상업 이용 가능 날씨 제공자 선택
6. AI 실행·알림 발송 진단 기록의 보관기간
7. 처리 완료된 신고 기록의 보관기간
8. UGC 보호 범위와 신고 운영 절차
9. 신고를 받을 운영 채널과 실제 수신 주소
10. 신고 검토 목표 시간과 운영 담당자
11. 외부 계정 삭제 요청의 본인 확인 방법
12. 외부 계정 삭제 요청의 처리 기한과 완료 통지 방법

현재 구현을 가장 적게 변경하면서 공식 약관을 충족하는 기본안은 다음과
같다.

- 서비스 가입과 이용은 만 14세 이상으로 제한한다.
- Cloudflare Workers AI의 계정·요금제·데이터 처리 조건을 공개 정책과
  실제 Supabase secret 구성에 일치시킨다.
- Open-Meteo 상업용 고객 엔드포인트와 API 키를 사용한다.
- AI 실행·알림 발송 진단 기록은 90일 후 삭제한다.
- 처리 완료된 신고 기록은 계정이 유지되는 동안 정해진 기간만 보관하고,
  계정 삭제 시 현재 구현처럼 함께 삭제한다.
- 공유 텍스트·이미지·오디오는 게시 전 검사하고, 검사 실패나 공급자
  장애 시 공개하지 않는다.
- 활성 차단 관계는 사용자가 차단을 해제하거나 계정을 삭제할 때까지
  유지한다.
- 외부 삭제 요청은 계정에 등록된 이메일로 본인을 확인하고 10일 이내에
  처리 결과를 같은 주소로 알린다.

신고 기록을 계정 삭제 뒤에도 보관하려면 신고자 식별자를 익명화하고
보관 목적·기간·법적 근거를 별도로 확정해야 한다. 현재 스키마는 이
방식을 지원하지 않으므로 운영 결정 없이 3년 보관을 적용하지 않는다.

이 기본안은 운영 결정 전 제안이며 공개 문구가 아니다.

## 4. 정책 웹 제공 경로

정책 웹은 최소한 다음 경로를 제공한다.

| 경로 | 목적 |
|---|---|
| `/` | 단짠 정책 및 지원 문서 진입점 |
| `/privacy` | 개인정보처리방침 |
| `/terms` | 서비스 이용약관 |
| `/safety` | 공유 콘텐츠와 신고·차단에 적용되는 안전 이용 약속 |
| `/account-deletion` | 앱 없이 계정 삭제를 요청하는 외부 경로 |
| `/support` | App Store Support URL과 일반 고객지원 진입점 |

계정 삭제 페이지에는 다음 내용을 포함한다.

- 앱 내부 삭제 경로
- 앱에 접근할 수 없는 사용자를 위한 이메일 삭제 요청 링크
- 본인 확인에 필요한 정보와 절차
- 삭제되는 데이터 범위
- 법령상 또는 안전 목적상 예외적으로 보관되는 데이터와 기간
- 요청 처리 예상 기간

고객지원 페이지에는 다음 내용을 포함한다.

- 실제로 수신하고 확인하는 공개 지원 이메일
- 앱에서 직접 해결할 수 있는 설정과 계정 관리 경로
- 로그인, 동기화, 알림, 위젯, AI와 안전 신고 문의 범위
- 계정 삭제 안내로 이동하는 경로
- 실제 운영 가능한 응답 기준

### 4.1 배포 구조

정책 웹은 서버 런타임을 사용하지 않는 Next.js 정적 출력으로 배포한다.
Cloudflare Pages에는 빌드 결과인 `out` 디렉터리만 공개하며 API 키, Supabase
서비스 역할 키와 같은 런타임 비밀값을 등록하지 않는다.

현재 모노레포를 Cloudflare Pages Git 연동으로 배포할 때 설정은 다음과 같다.

| 항목 | 값 |
|---|---|
| Production branch | `main` |
| Root directory | `apps/policy-web` |
| Build command | `npm run build:release` |
| Build output directory | `out` |
| `NODE_VERSION` | `22.19.0` |

`apps/policy-web`을 별도 저장소로 분리하면 Root directory만 비워 두고 나머지
값은 유지한다. 최초 `pages.dev` 주소를 앱이나 스토어에 등록한 뒤 커스텀
도메인으로 변경하는 경우, 이미 배포된 앱을 위해 이전 주소를 유지하거나 새
주소로 리다이렉트한다.

Cloudflare Pages Git 연동과 정적 요청 과금 기준은 다음 공식 문서를 따른다.

- https://developers.cloudflare.com/pages/configuration/git-integration/
- https://developers.cloudflare.com/pages/functions/pricing/
- https://developers.cloudflare.com/pages/configuration/custom-domains/

## 5. 배포 승인 조건

다음 조건을 모두 충족한 경우에만 정책 웹을 배포한다.

- 위 운영 결정이 모두 확정됨
- 공개 문서와 `privacy-data-map.md`가 일치함
- Cloudflare Workers AI와 날씨 API의 운영 계약이 실제 배포 설정과 일치함
- 앱 내부 계정 삭제 결과와 외부 안내 문구가 일치함
- 정책 URL이 모바일과 데스크톱에서 읽기 가능함
- 정책 페이지에 임시 문구나 미확정 값이 없음
- `/safety` 문서와 앱에서 동의받는 정책 버전·내용이 일치함
- 신규 신고가 실제 운영 채널로 전달되고 재시도·실패를 확인할 수 있음
- 앱 설정에 개인정보처리방침과 이용약관 링크가 연결됨
- 앱 설정에 고객지원 링크가 연결됨
- App Store Connect의 Support URL이 `${POLICY_BASE_URL}/support`로
  연결되고 공개 이메일로 실제 문의할 수 있음
- App Store Connect와 Play Console의 Privacy Policy URL이
  `${POLICY_BASE_URL}/privacy`로 연결됨
- Play Console의 외부 계정 삭제 URL이
  `${POLICY_BASE_URL}/account-deletion`로 연결됨

## 6. 공식 자료

- 개인정보보호위원회, 개인정보 처리방침 작성지침(2026.4. 개정):
  https://www.pipc.go.kr/np/cop/bbs/selectBoardArticle.do?bbsId=BS217&mCode=D010030000&nttId=12018
- 개인정보 보호법 제21조:
  https://law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1029335625
- 개인정보 보호법 제36조:
  https://law.go.kr/lsLinkCommonInfo.do?chrClsCd=010202&lsJoLnkSeq=1029335317
- 개인정보 보호법 시행령 제43조:
  https://www.law.go.kr/LSW/lsLawLinkInfo.do?chrClsCd=010202&lsJoLnkSeq=900077157
- 개인정보 보호법 시행령 제31조:
  https://www.law.go.kr/LSW/lsLawLinkInfo.do?chrClsCd=010202&lsJoLnkSeq=900079801
- Apple App Review Guidelines:
  https://developer.apple.com/app-store/review/guidelines/
- Apple App Store Connect 필수 속성:
  https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/
- Apple 계정 삭제 안내:
  https://developer.apple.com/support/offering-account-deletion-in-your-app
- Google Play 고객지원 요구사항:
  https://support.google.com/googleplay/android-developer/answer/113477
- Google Play 계정 삭제 요구사항:
  https://support.google.com/googleplay/android-developer/answer/13327111
- Cloudflare Workers AI 데이터 사용:
  https://developers.cloudflare.com/workers-ai/platform/data-usage/
- Cloudflare Workers AI 가격:
  https://developers.cloudflare.com/workers-ai/platform/pricing/
- Open-Meteo 이용 조건:
  https://open-meteo.com/en/terms
- Supabase 프로젝트 리전:
  https://supabase.com/docs/guides/platform/regions
