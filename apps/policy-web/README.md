# 단짠 정책 웹

단짠의 개인정보처리방침, 서비스 이용약관, 안전 이용 약속, 계정 삭제와
고객지원 안내를 제공하는 정적 웹사이트다.

## 요구 환경

- Node.js `>=22.13.0`

## 명령어

```bash
npm ci
npm run dev
npm run build
npm run build:release
npm test
npm run lint
```

`npm run build`는 개발 및 검증용 정적 파일을 `out`에 생성한다.
`npm run build:release`는 `policy-release-state.json`의 운영 결정과 공개 문서
상태를 먼저 검사하며, 출시 준비가 끝난 경우에만 같은 정적 산출물을 만든다.

## 공개 경로

- `/`: 정책 및 지원 문서 진입점
- `/privacy`: 개인정보처리방침
- `/terms`: 서비스 이용약관
- `/safety`: 안전 이용 약속
- `/account-deletion`: 계정 삭제 안내
- `/support`: 고객지원 안내

## Cloudflare Pages 배포

이 사이트는 서버 함수 없이 `out` 디렉터리만 배포한다. Cloudflare Pages의
Git 연동 프로젝트에는 다음 값을 사용한다.

| 항목 | 현재 모노레포 | 별도 저장소로 분리한 경우 |
| --- | --- | --- |
| Production branch | `main` | `main` |
| Root directory | `apps/policy-web` | 비워 둠 |
| Build command | `npm run build:release` | `npm run build:release` |
| Build output directory | `out` | `out` |
| `NODE_VERSION` | `22.19.0` | `22.19.0` |

첫 배포 후 `<project-name>.pages.dev` 주소가 생성된다. 커스텀 도메인은 이후
Cloudflare Pages의 Custom domains에서 연결할 수 있다. 앱과 스토어에 등록한
기존 주소를 교체할 때는 이미 배포된 앱을 위해 이전 주소도 계속 접근 가능하게
유지하거나 새 주소로 리다이렉트한다.

정적 정책 사이트에는 런타임 비밀값이 필요하지 않다. API 키나 Supabase
서비스 역할 키를 Pages 환경 변수 또는 클라이언트 산출물에 추가하지 않는다.

공개 문서는 `docs/release/privacy-data-map.md`와 실제 서비스 동작을 기준으로
작성한다. 현재 정책 문서는 운영 결정을 반영한 `ready` 상태이며,
`build:release` 검증을 통과한 정적 산출물만 공개한다. 실제 공개 URL 배포와
스토어 등록 완료 여부는 `docs/release/store-submission-checklist.md`에서 별도로
관리한다.
