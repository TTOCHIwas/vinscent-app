# 월간 회고 화면 개선 기기 설치·운영 반영

## 소스와 검증

- 배포 소스: `817ac8e22898b3dcfb9aa9b60888054602b78aea` (`main`).
- 기능: `4b8f9e37`, 테스트: `ee98bb3c`, 명세: `817ac8e2`.
- Flutter 전체 테스트 1,276개 통과, 기존 1개 건너뜀. 정적 분석 지적 없음.
- 격리 Postgres 전체 47파일·955개 테스트 통과. DB 오류 수준 검사 지적 없음.
- 원격 CI: [38887318998](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38887318998), 성공. Flutter 형식·정적 분석·전체 테스트와 Node 검사 통과.

## 기기 설치

- 연결 기기: Galaxy S24 (`SM-S921N`), arm64.
- 패키지: `com.vinscent.vinscent`.
- 버전: `1.0.0 (2026101602)`, 테스트용 debug APK.
- `adb install -r` 성공. 기존 앱 데이터 유지.
- 실제 설치 버전과 `am start -W`의 `Status: ok` 확인. 실행 프로세스 유지 및 초기 오류 검색 결과 0건.
- 카드 더미, 가로 장면 배치, 공통 헤더와 월별 진입 조건을 반영했다. 실제 화면의 최종 사용성 확인은 기기에서 진행한다.

## 운영 조회 migration

- 대상: 기존 운영 프로젝트 `bovpxpmcjxcwlbpwmdck`.
- `20261016101359_add_monthly_retrospective_availability.sql`이 `get_current_monthly_retrospective_availability()`를 추가한다.
- 인증된 사용자의 활성 커플에 한해 대상 월·만료·기록 존재 여부만 반환한다. 회고·캐시·기본 질문을 생성하거나 고정하지 않고, 답변 원문을 반환하지 않는다.
- 사용자에게 main 커밋·푸시 및 조회 migration 운영 반영을 명시적으로 승인받았다. [기존 보호된 Supabase 배포 workflow](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38888206773)가 동일 소스 SHA로 성공했다.
- 운영 migration 등록, stable 읽기 함수, 빈 search_path, 사용자 식별 검사, authenticated 실행 허용·anon 실행 차단을 원격에서 확인했다. 기존 사용자 기록을 수정하는 데이터 migration은 없다.
- 배포 후 보안 advisor를 확인했다. 직접 테이블 접근을 막는 RLS·인증 RPC의 SECURITY DEFINER 경고는 기존 API 경계와 함께 검토했고, 신규 함수는 활성 커플 범위·인증·원문 미반환을 검증했다. 일반 경고의 설명은 [인증된 SECURITY DEFINER RPC](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [search_path](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable), [비밀번호 보호](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)를 참고한다. 이번 작업에서 기존 인증 설정이나 테이블 정책은 변경하지 않았다.
- Google Play·TestFlight에는 이번 빌드를 배포하지 않는다.

## 독립 회고 화면 후속 재설치

- 소스: 위 배포 커밋 이후 작업 트리의 독립 회고 화면·헤더·하단 정보 배치 변경. 아직 커밋·푸시하지 않았다.
- Flutter 전체 테스트 1,297개 통과, 기존 1개 건너뜀. 정적 분석 지적 없음, 코드 리뷰 통과.
- 사용자 요청으로 같은 Galaxy S24에 `1.0.0 (2026101603)` debug arm64 APK를 `adb install -r`로 설치했다. 기존 앱 데이터 유지.
- 실제 설치 버전과 `am start -W`의 `Status: ok` 확인. 이번 후속 변경으로 DB·운영 함수·스토어 배포는 수행하지 않았다.

## 단일 스크롤 회고 재설치

- 소스: 작업 트리의 소개·대화·기억·회고 입력 단일 화면, 캘린더와 같은 헤더/날짜 스타일, 96px 캐릭터 및 AI 독 선택 변경. 아직 커밋·푸시하지 않았다.
- Flutter 전체 테스트 1,299개 통과, 기존 1개 건너뜀. 정적 분석 지적 없음, 코드 리뷰 통과.
- 사용자 요청으로 같은 Galaxy S24에 `1.0.0 (2026101604)` debug arm64 APK를 `adb install -r`로 설치했다. 기존 앱 데이터 유지.
- 실제 설치 버전과 `am start -W`의 `Status: ok`, 실행 프로세스 및 초기 오류 검색 0건 확인. DB·운영 함수·스토어 배포는 수행하지 않았다.

## 섹션 안내·여백 개선 재설치

- 소스: 작업 트리의 네 섹션 이름·설명, 64px 구분 간격 및 소개 안내 높이를 반영한 카드 배치 변경. 아직 커밋·푸시하지 않았다.
- 회고·라우팅·캘린더 관련 테스트 108개 통과. 정적 분석·포맷 검사·코드 리뷰와 라이트 테마 렌더링 확인 완료.
- 사용자 요청으로 같은 Galaxy S24에 `1.0.0 (2026101605)` debug arm64 APK를 `adb install -r`로 설치했다. 기존 앱 데이터 유지.
- 실제 설치 버전, `am start -W`의 `Status: ok`, 실행 프로세스와 초기 오류 검색 0건 확인. DB·운영 함수·스토어 배포는 수행하지 않았다.

## 타이포·정보 계층 정리 재설치

- 소스: 작업 트리의 소개·공동 답변 안내 제거, 날짜 옆 선정 이유, 제목·통계·요약 간 여백 및 역할별 타이포 변경. 아직 커밋·푸시하지 않았다.
- 관련 테스트 134개, 정적 분석·포맷 검사·코드 리뷰 통과. 실제 글꼴과 테스트 데이터로 라이트 화면 배치를 확인했다.
- 사용자 요청으로 같은 Galaxy S24에 `1.0.0 (2026101606)` debug arm64 APK를 `adb install -r`로 설치했다. 기존 앱 데이터 유지.
- 실제 설치 버전과 `am start -W`의 `Status: ok`, 실행 프로세스 및 초기 오류 검색 0건 확인. DB·운영 함수·스토어 배포는 수행하지 않았다.
