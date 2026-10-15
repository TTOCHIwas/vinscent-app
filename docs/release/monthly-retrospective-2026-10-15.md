# 월간 회고 화면 개편·기기 설치

## 소스와 검증

- 소스: `a9a13e69f0cc69a5208ab574556701cb8875a12d`.
- 구현: `c171ed4f`, 테스트: `7f0a078b`, 명세: `a9a13e69`.
- [CI](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38731300103): 성공.
- 로컬 검증: Flutter 전체 회귀 통과(기존 조건부 1개 건너뜀), 최종 회고 테스트 13개, embedded DB 14개, 실제 PostgreSQL 46파일·938개 통과. Flutter analyze·DB lint·DB advisors 오류 수준 이상 없음. 코드 리뷰 승인.

## 연결 기기 설치

- 기기: Galaxy S24 (`SM-S921N`).
- 앱: `com.vinscent.vinscent`, `1.0.0 (2026101501)`, debug APK.
- 사용자 USB 디버깅 허용 후 `adb install -r` 성공.
- `MainActivity` 실행과 프로세스 유지 확인. 조회한 시작 로그에 `FATAL EXCEPTION`, `E/flutter`, `Unhandled Exception`, `AndroidRuntime` 오류 없음.
- APK SHA-256: `48aec1074c389ab4f9a4b8325b52dd873e0ab8e8a81278613f91cbc86bd6723f`.
- 설치 확인 시각: 2026-10-15 21:03 KST.

이는 설치·시작 확인이다. 사용자가 기기에서 수행하는 페이지 전환·카드 확인·답변 입력 검증은 아직 통과로 기록하지 않는다. Google Play 내부 트랙이나 TestFlight에 새 빌드를 올린 것은 아니다.

## 운영 조회 확장

사용자가 기기에서 지난달 전체 카드를 확인할 수 있도록 운영 조회 migration 적용을 별도로 승인했다.

- 대상: `bovpxpmcjxcwlbpwmdck` (`danjjan`). 앱 설정의 운영 host와 일치 확인.
- 대상 migration: `20261015112808_add_monthly_retrospective_gallery.sql`.
- 적용 전 원격 최신 migration: `20261011143000_connect_monthly_retrospective`.
- 적용 전 `private.monthly_retrospective_gallery(uuid,date)` 없음 확인.
- [운영 배포](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38732588662): 성공.
- 원격 확인: migration 적용, gallery 함수 존재, 기존 회고 응답의 gallery 필드, 인증된 회고 조회 허용, gallery helper 직접 실행 차단 모두 확인.

기존 저장·삭제·카운트·대표 카드 보관 정책은 유지하고, 기존 회고 응답에 지난달 보관 대표 카드의 `gallery`를 추가한다.
