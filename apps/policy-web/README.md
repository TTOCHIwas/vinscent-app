# 단짠 정책 웹

단짠의 개인정보처리방침, 서비스 이용약관, 안전 이용 약속, 계정 삭제와
고객지원 안내를 공개하는 정적 웹 애플리케이션이다.

## 요구 환경

- Node.js `>=22.13.0`

## 명령어

```bash
npm install
npm run dev
npm run build
npm run build:release
npm test
npm run lint
```

`build:release`는 `policy-release-state.json`의 운영 결정이 모두 해결되고
정책 페이지에서 초안 표시가 제거된 경우에만 공개용 빌드를 만든다. 현재
초안 상태에서는 실패하는 것이 정상이다. 일반 `build`는 공개 전 문서의
렌더링과 테스트를 위해 계속 사용할 수 있다.

## 문서 경로

- `/`: 정책 및 지원 문서 진입점
- `/privacy`: 개인정보처리방침
- `/terms`: 서비스 이용약관
- `/safety`: 안전 이용 약속
- `/account-deletion`: 계정 삭제 안내
- `/support`: 고객지원 안내

공개 문서는 `docs/release/privacy-data-map.md`와 실제 서비스 동작을
기준으로 작성한다. 운영자 정보와 외부 서비스 계약이 확정되기 전에는
배포하지 않는다.
