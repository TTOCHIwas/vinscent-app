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
