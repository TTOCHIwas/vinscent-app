# Windows 합성 한국어 콘텐츠 검사 평가

실행일: 2026-10-25 23:12 KST.

## 실행 기준

- 브랜치: `codex/content-safety-foundation`
- HEAD: `95a1154c323d4460d5ef15053dfdaba814a4796c`
- 환경: Windows, Node `v22.19.0`
- 사전 검증: AI 서비스 테스트 332개 통과, 실패·건너뜀 0개. 기본 평가 계획은 외부 요청 0건.
- 원래 작업 디렉터리의 main과 기존 미추적 파일은 보존하고 별도 worktree에서 실행했다.
- 입력: `eval/fixtures/content-safety-ko.ts`의 동일 합성 한국어 18개. 기대 허용 12개, 기대 차단 6개.
- 공급자별 1회, 문장별 순차 요청, 자동 재시도 0회. OpenAI 다음 Cloudflare 순으로 실행했다.
- 기존 `evaluateContentSafety` → `CheckSharedContent` → 공급자 어댑터 → HTTP 호출 경로를 사용했다.
- 사례별 제한 시간 15초. Cloudflare 설정은 temperature 0, max_tokens 128이다.
- CLI와 같은 평가 함수를 호출하고 주입한 fetcher로 사례 ID·HTTP 상태·네트워크 실패 여부만 추가 수집했다.
- 키는 Git 추적에서 제외된 로컬 파일을 평가 프로세스에만 로드했다. Secret 원문과 공급자 응답 본문은 기록하지 않았다.
- 보고서 모델명은 요청한 설정값이다. 응답의 실제 모델 snapshot은 수집하지 않았다.

## 결과

| 항목 | OpenAI | Cloudflare |
| --- | --- | --- |
| 설정 모델 | `omni-moderation-latest` | `@cf/meta/llama-guard-3-8b` |
| 기대 판정 일치 | 18/18 | 18/18 |
| 오허용 | 0/6 | 0/6 |
| 오차단 | 0/12 | 0/12 |
| 판정 불가 | 0/18 | 0/18 |
| HTTP 200 | 18/18 | 18/18 |
| p50 | 527 ms | 299 ms |
| p95 | 1,421 ms | 694 ms |

사례별 기대·실제 판정, 지연 시간과 HTTP 상태는 [OpenAI 결과](openai.json)와
[Cloudflare 결과](cloudflare.json)에 기록했다. 보고서에 입력 원문은 포함하지 않았다.

정상 일상·연애·관용구·갈등 표현 12개는 모두 허용했고, 위협·강요·혐오 6개는 모두 차단했다.
인증·권한·호출 제한·네트워크 오류는 이번 요청에서 관측되지 않았다.
계정의 잔여 사용량과 실제 청구액은 조회하지 않았으므로 보고하지 않는다.

## 해석과 공급자 판단

이 표본에서는 판정 차이가 없었고 Cloudflare의 지연 시간이 더 짧았다.
18개 라벨은 검토용 초안이며 단일 실행 결과로 한국어 전체 품질 우위나 운영 공급자를 확정하지 않는다.
동일 Windows에서 실행했지만 두 공급자는 동시에 측정하지 않았고 실행 순서도 교차하지 않았다.
네트워크·초기 연결 영향을 분리하지 않았다. p95는 현재 집계 방식상 18개 중 최댓값이다.

이미지와 음성은 전송하거나 평가하지 않았다. 이번 결과는 텍스트 평가에 한정한다.
OpenAI는 텍스트·이미지 입력을 지원하지만 음성을 직접 분류하지 않는다.
Cloudflare Llama Guard 후보는 텍스트 검사 후보다. 멀티모달 지원 범위와 품질은 별도 판단한다.
게시 전 검사 모듈은 실제 DB/Storage 공개 경계에 연결되지 않았으므로 출시 차단 항목 전체가 해결된 상태가 아니다.

## 다음 구현 범위

1. 현재 라벨과 제품 차단 기준을 검토하고 이미지·음성 평가 범위를 정한다.
   이미지 속 글·분류별 지원 범위, 전사 실패·침묵·잡음과 비용·보관·외부 처리자 조건을 포함한다.
2. 공급자와 정책을 확정한 뒤 DB/Storage 공개 경계의 실패 테스트부터 작성한다.
   작성자 전용 초안, 불변 snapshot, claim/revision, 내용 hash와 정책 버전에 묶인 승인,
   승인된 동일 버전의 원자적 공개와 Storage 읽기 차단을 검증한다.
3. gateway와 서버 공개 경계를 구현하고 기존 모바일·Android/iOS 위젯 저장 경로를 연결한다.
   대기·거절·오류 상태에서도 작성자의 초안을 유지하고 재시도 흐름을 제공한다.
4. 직접 RPC/Storage 접근, 검사 중 수정·삭제·관계 종료, signed URL,
   알림·Realtime·홈 위젯의 승인 전 노출을 회귀 검증한다.
5. 실제 처리 경로에 맞춰 정책·동의 안내를 정리하고 macOS/Xcode 및 실기기에서 검증한다.

이번 실행에서 변경한 것은 평가 결과 JSON 2개와 이 보고서뿐이다.
제품 코드, 운영 DB, Storage 정책, Edge Function 배포, 기존 운영 Secrets와 앱 배포는 변경하지 않았다.
후속 구현은 아직 수행하지 않았고 운영 반영·앱 배포는 별도 승인이 필요하다.

## 공식 사양 확인

- [OpenAI Moderation](https://developers.openai.com/api/docs/guides/moderation)
- [OpenAI 모델·호출 제한](https://developers.openai.com/api/docs/models/omni-moderation-latest)
- [Cloudflare Llama Guard](https://developers.cloudflare.com/workers-ai/models/llama-guard-3-8b/)
- [Cloudflare 호출 제한](https://developers.cloudflare.com/workers-ai/platform/limits/)
- [Cloudflare 요금](https://developers.cloudflare.com/workers-ai/platform/pricing/)
