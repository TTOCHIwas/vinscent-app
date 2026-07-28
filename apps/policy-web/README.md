# 단짠 정책 웹

단짠의 개인정보처리방침, 서비스 이용약관, 계정 삭제 안내를 공개하는
정적 웹 애플리케이션이다.

## 요구 환경

- Node.js `>=22.13.0`

## 명령어

```bash
npm install
npm run dev
npm run build
npm test
npm run lint
```

## 문서 경로

- `/`: 정책 및 지원 문서 진입점
- `/privacy`: 개인정보처리방침
- `/terms`: 서비스 이용약관
- `/account-deletion`: 계정 삭제 안내

공개 문서는 `docs/release/privacy-data-map.md`와 실제 서비스 동작을
기준으로 작성한다. 운영자 정보와 외부 서비스 계약이 확정되기 전에는
배포하지 않는다.
