# 월간 회고 운영·베타 배포 기록

## 배포 소스

- 배포 승인: 운영 반영, Android 내부 테스트 및 iOS TestFlight 배포 요청.
- 저장소: `TTOCHIwas/vinscent-app`, `main`.
- 소스 SHA: `ecba1a343deb36369b6e245a584fc4ccb31c6e67`.
- 모바일 앱 버전: `1.0.0`.

## 자동 검증

| 검증 | 결과 |
| --- | --- |
| [최종 소스 전체 CI](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38140628385) | 성공 |
| Flutter 테스트·정적 분석 | 1,255개 통과, 기존 조건부 테스트 1개 건너뜀; 분석 오류·경고 없음 |
| AI 서비스 테스트 | 283개 통과 |
| Edge 함수 테스트 | 129개 통과 |
| 릴리스 계약 테스트 | 77개 통과 |
| 정책 테스트 | 16개 통과 |
| 전체 Supabase migration 적용 후 pgTAP | 45개 파일, 928개 테스트 통과 |
| 실제 로컬 PostgreSQL DB lint | 오류 없음 |
| Embedded PostgreSQL 월간 회고 계약 | 13개 통과 |
| Android 앱 모듈 네이티브 단위 테스트 | 23개 통과 |

전체 DB 검증은 기존 개발 DB와 분리한 `vinscent_monthly_release` 프로젝트에서 수행했다. 검증 후 이 임시 프로젝트만 종료했고 기존 개발 스택은 보존했다.

DB 전체 테스트 중 embedded fixture가 pgTAP 테스트로 잘못 발견되는 문제가 재현됐다. fixture를 `supabase/test-fixtures/`로 이동하고 테스트 탐색 경계 회귀 검증을 추가했다. 수정 후 전체 DB 테스트를 다시 통과했다.

## 운영 Supabase

- 프로젝트: `bovpxpmcjxcwlbpwmdck` (`danjjan`).
- [운영 배포](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38141156242): 성공.
- 신규 migration: `20261011112004_add_monthly_retrospective`, `20261011143000_connect_monthly_retrospective`.
- Edge 함수: 월간 회고 생성 추가 및 기존 13개 함수를 포함한 배포 inventory 확인 완료.
- 원격 권한: 인증된 회고 조회·저장 RPC 허용, 생성 준비 함수 접근 제한, 답변 테이블 직접 접근 및 익명 접근 차단 확인.
- 캐시 정리: `purge-expired-monthly-retrospectives`, `5 * * * *`, 활성 상태 확인.
- 생성 엔드포인트: 인증 없는 요청에 `401 unauthorized` 반환 확인.
- 배포 artifact: `danjjan-supabase-ecba1a343deb36369b6e245a584fc4ccb31c6e67`.
- artifact digest: `sha256:93116a298ab7c4a497ee5bcd01c465627185f7dc681917343d437dc48c04a3e6`.

카드 집계 시작 시각은 `2026-10-11T12:56:23.451272Z`다. 한국 시간 기준 9월과 10월은 전체 작성 수를 복원할 수 없어 집계 불가로 표시한다. 첫 완전한 11월 카드 통계는 12월에 제공되는 회고부터 표시한다.

## 모바일 배포

| 대상 | 실행 | 빌드 번호 | 상태 |
| --- | --- | --- | --- |
| iOS 서명 후보 | [38140630423](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38140630423) | `2026101101` | 성공, 업로드 없음 |
| Android 내부 테스트 | [38141274680](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38141274680) | `2026101102` | 성공, internal 트랙 completed 릴리스 commit 확인 |
| iOS TestFlight | [38141955159](https://github.com/TTOCHIwas/vinscent-app/actions/runs/38141955159) | `2026101102` | 업로드 성공; Apple 처리·내부 테스터 배포 상태 미확인 |

iOS 후보를 내려받아 IPA·archive·entitlement·privacy 목록의 SHA-256 5개를 모두 검증했다. 앱과 위젯 식별자, production push, App Group, Apple 로그인 권한 및 디버그 허용 해제 상태를 확인한 뒤 같은 소스를 새 빌드 번호로 TestFlight에 업로드하는 실행을 시작했다. Apple 업로드 성공과 빌드 처리·테스터 배포 상태는 따로 기록한다.

- 후보 artifact digest: `sha256:ad03bb5738db93ea3f345ad92b76e19faf0b73464ce9b28068b364d62261fc60`.
- 후보 IPA SHA-256: `aa1dc4ae5941484b7382767a9d46fb3f645758d1c31efe59a368276d8a5870a0`.
- 후보 archive SHA-256: `79062532d92fd8eb380f6d581ff5ee82e2a28104f9e25b94edc173912f91bdb0`.
- 후보 도구: Xcode `26.6`, iPhoneOS SDK `26.5`, Flutter `3.41.9`.

Android는 `internal`, `completed`, `단짠 1.0.0 (2026101102)` 릴리스로 `2026-10-11T13:27:52Z`에 Google Play edit commit 성공을 확인했다. AAB·mapping·manifest·16KB 검증·파일 목록·서명 보고서의 SHA-256 6개를 내려받아 검증했다. 업로드 인증서와 Play 인증서 일치, 인증서 유효 기간, native debug symbol 및 mapping 포함 검증도 통과했다.

- Android artifact digest: `sha256:b295758a6022f8f522aa2ab8853f75b43e6be20ad09e400b94bd81222ab0273e`.
- Android AAB SHA-256: `808f42dc256d92f6bec50e21a9eceb8b62aa8c879cc4c50422c35484302afd03`.
- Android min SDK `24`, target SDK `36`, page alignment `16KB`.
- Google Play edit ID: `03553270348623539266`.

실제 TestFlight 업로드는 `2026-10-11T13:23:06Z`에 Apple의 `UPLOAD SUCCEEDED with no errors` 응답을 확인했다. 배포 IPA·archive·entitlement·privacy 목록의 SHA-256 5개도 내려받아 검증했다.

- 배포 artifact digest: `sha256:5cdd6a7c22a4486cc380fb98b54fa3a254748af1b90945ac73908656980cd146`.
- 배포 IPA SHA-256: `765f83dbecd0836759c8db6529948a654367ec8d38630cef5224ae14347138e0`.
- 배포 archive SHA-256: `5b3d8ad10b5b53c98408ab1fe96c67525898f58684cfdd690476bfae7c8cc173`.
- Apple delivery UUID: `8a40c9e7-8dcb-45b3-a395-9628763ca47d`.

App Store Connect는 암호 입력이 필요한 로그인 페이지에 있어 Apple 처리 완료, 내부 그룹의 빌드 배정·자동 배포 여부는 확인하지 못했다. 기존 인증·서명 자산은 변경하지 않았으며, 로그인 후 TestFlight의 실제 상태를 확인해야 한다.

## 실제 기기에서 남은 확인

현재 환경에는 실행 가능한 Android 기기·에뮬레이터 및 iPhone이 없어 실기기 검증은 미수행이다. 자동 테스트와 서명된 릴리스 빌드 성공을 실기기 성공으로 기록하지 않는다.

베타 앱을 설치한 두 계정으로 다음 항목을 확인한다.

1. AI 질문과 월간 회고 전환, 기존 AI 질문·캘린더 동작.
2. 지난달 통계, 집계 불가 표시, 0~3개 장면 및 원래 날짜 기록 진입·복귀.
3. 공동 답변이 없는 달의 우리의 답 생략, 선택 질문·답변 원문 표시.
4. 같은 회고 질문 제공, 내 답변 저장·재열람·수정 및 상대 답변 공개 경계.
5. 두 기기의 답변 수정 충돌, 초안 유지 및 이동 시 종료 확인.
6. 동의 변경·관계 종료·월 경계의 조회 및 저장 제한.
7. 라이트 테마, 작은 화면·큰 글자·키보드에서 네 페이지 배치.
8. 실제 모델의 제목·요약·질문이 공개된 기록에 근거하는지 확인.

실제 모델 품질 확인과 사람의 베타 테스트 결과는 아직 통과로 기록하지 않았다.
