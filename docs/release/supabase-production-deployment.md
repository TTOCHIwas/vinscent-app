# Supabase 프로덕션 배포 절차

이 문서는 `.github/workflows/supabase-production.yml`을 이용해 단짠의
Database migration과 Edge Function을 같은 Git commit 기준으로 운영
Supabase에 배포하는 절차를 정리한다. 운영 배포는 자동 push가 아니라
승인된 수동 실행만 허용한다.

## 1. GitHub Environment 준비

GitHub 저장소에 `supabase-production` Environment를 만들고 다음 보호
규칙을 적용한다.

- 필요한 경우 배포 승인자를 지정한다.
- 배포 가능한 branch를 `main`으로 제한한다.
- 팀을 운영한다면 배포 요청자가 자신의 요청을 단독 승인하지 못하게 한다.

Environment에는 다음 값을 등록한다.

| 종류 | 이름 | 내용 |
|---|---|---|
| Secret | `SUPABASE_ACCESS_TOKEN` | 운영 프로젝트에 접근 가능한 Supabase personal access token |
| Secret | `SUPABASE_DB_PASSWORD` | 운영 프로젝트 Database password |
| Variable | `SUPABASE_PROJECT_ID` | 운영 프로젝트의 20자 project ref |

값 자체는 저장소, workflow 입력, 이슈, 로그 또는 배포 증빙에 기록하지
않는다. Project ref는 비밀값은 아니지만 잘못된 프로젝트 배포를 막기 위해
보호된 Environment variable로 고정한다.

## 2. 배포 전 조건

다음 조건을 모두 확인한 뒤 실행한다.

- 배포할 commit이 원격 `main`에 존재한다.
- 해당 commit의 경량 `CI` 체크가 통과했다.
- Docker 호환 런타임이 있는 개발 환경에서
  `.\scripts\verify_database_local.ps1` 전체 검증이 통과했다.
- migration은 이미 적용된 동작을 깨지 않는 전진 호환 변경이다.
- Edge Function이 새 schema에 의존한다면 migration 적용 뒤에도 이전
  함수가 잠시 동작할 수 있는 경계를 유지한다.
- `supabase/runtime-environment.manifest.json`의 필수 secret 이름이 운영
  프로젝트에 등록되어 있다.
- 운영 secret 값은 로그에 노출하지 않고 `supabase secrets list`가 반환한
  이름만 런타임 환경 매니페스트와 대조한다.
- Supabase가 자동 제공하는 `SUPABASE_*` 항목을 제외한 사용자 관리
  secret은 매니페스트에 없는 오래된 이름도 남아 있지 않아야 한다.

## 3. 실행 방법

1. GitHub Actions에서 `Supabase production release`를 선택한다.
2. 실행 branch로 `main`을 선택한다.
3. `commit_sha_confirmation`에 배포할 40자 소문자 commit SHA를 입력한다.
4. `project_ref_confirmation`에 운영 project ref를 입력한다.
5. workflow를 실행하고 `supabase-production` 승인을 완료한다.

입력한 commit 또는 project ref가 보호된 값과 다르면 배포 전에
중단된다.

## 4. 배포 안전 검사와 실행 순서

Edge Function 단위 테스트·Deno type check와 빈 Database migration·pgTAP·
Database lint는 CI 및 로컬 검증 단계의 책임이다. 운영 배포는 Docker 기반
검증을 반복하지 않는다. `deploy`는 Environment 승인 뒤 다음 순서로
실행한다.

1. 입력한 commit, workflow commit과 `main` branch의 정확한 일치 확인
2. checkout된 HEAD와 workflow commit의 일치 및 깨끗한 worktree 확인
3. 런타임 환경 매니페스트와 실제 Edge Function 참조 대조
4. 보호된 project ref와 입력값 대조 후 운영 project 연결
5. 운영 Edge secret 이름과 필수·fallback 계약 확인
6. 저장소에 없는 원격 Edge Function 존재 여부 확인
7. 저장소에 없는 원격 migration 이력이 없는지 확인하되 아직 적용하지
   않은 로컬 migration은 허용
8. `db push --dry-run`
9. pending migration 전진 적용
10. 저장소의 모든 Edge Function 배포
11. 로컬·원격 migration 버전, Edge Function 목록과 `verify_jwt` 모드의
   정확한 일치 확인
12. source commit과 worktree를 다시 확인하고 migration·function 목록과 파일
   hash 증빙 업로드

원격에만 남은 함수는 자동 삭제하지 않는다. 해당 함수의 호출자와 운영
상태를 확인한 뒤 별도 변경으로 제거한다. `--prune`, `db reset`,
`--include-all`은 이 workflow에서 사용하지 않는다.

## 5. 배포 증빙

성공한 실행은 90일 동안 다음 artifact를 보관한다.

- 배포 commit SHA, run ID, project ref와 UTC 시각
- Supabase CLI version
- 검증된 원격 migration JSON 목록
- 원격 Edge Function 목록
- 저장소 migration과 function source의 SHA-256
- GitHub artifact digest

이 증빙에는 Database password, access token, Edge secret 값이 포함되지
않는다.

## 6. 배포 뒤 확인

배포 직후 다음 운영 검증을 별도로 수행한다.

- `supabase/snippets/audit_edge_runtime_resources.sql` 결과가 모두 `ready`
- Database Webhook과 Cron이 기대한 함수를 호출함
- AI worker, 알림, 정리 worker와 신고 운영 알림의 수동 smoke test
- 앱 두 계정에서 로그인, 카드·녹음·질문·일정 실시간 동기화
- 계정 삭제와 커플 연결 해제·즉시 삭제

이 workflow는 Edge secrets, Database Webhook, Cron과 외부 운영
수신기를 생성하거나 변경하지 않는다. 해당 운영 리소스는
`docs/release/supabase-runtime-configuration.md`의 대조 절차를 따른다.

## 7. 실패와 복구

Database와 Edge Function은 하나의 원자적 트랜잭션으로 배포되지 않는다.
중간 실패 시 `db reset`이나 migration history 수정을 사용하지 않는다.

- migration 실패: 원인을 수정한 새 migration을 `main`에 추가한다.
- migration 성공 후 함수 실패: 기존 함수와 호환되는 schema를 유지한 채
  함수 오류를 수정해 다시 배포한다.
- 함수 회귀: 이전 동작을 복구하는 새 commit을 `main`에 반영해 다시
  실행한다.
- 원격 전용 함수 발견: 호출자를 확인하고 명시적인 삭제 변경으로
  처리한다.

## 8. 공식 근거

- Supabase 환경과 migration CI/CD:
  https://supabase.com/docs/guides/deployment/managing-environments
- Edge Function CI/CD 배포:
  https://supabase.com/docs/guides/functions/deploy
- Supabase CLI `db push`:
  https://supabase.com/docs/reference/cli/supabase-db-pull
- GitHub Actions 보안 사용 지침:
  https://docs.github.com/en/actions/reference/security/secure-use
