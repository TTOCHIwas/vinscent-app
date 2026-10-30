# Vinscent AI API

This service owns the model-independent learning boundary for Vinscent.

`LearningModelPort` keeps application and domain code independent from a model
provider. The deployed AI Edge Functions connect `StructuredLearningModel` to
Cloudflare Workers AI with Mistral Small 3.1 24B. Qwen, Gemini, Groq, and
OpenAI adapters stay available for provider comparison and regression
evaluation.
Replacing the provider must not change prompts, job repositories, or domain
contracts. Provider adapters translate native failures into
`StructuredGenerationError`; the shared learning model then exposes only
`LearningModelError` to job handlers.

`LearningJobProcessor` owns only claim and run lifecycle orchestration.
Task-specific context loading, model calls, validation, and output mapping are
registered through `LearningJobHandlerRegistry`.

Proactive suggestions follow the same boundary: the Edge Function is only a
composition root, the HTTP handler owns transport concerns, and
`GenerateProactiveSuggestionUseCase` owns server-date context and lifetime
rules. Device-local dates are not used for daily suggestion limits.

The database remains authoritative for consent, job claims, memory
confirmation, feature entitlements, question recommendations, and question
assignment. A worker re-checks consent immediately before reading completed
answers and before persisting a result.

Model adapters receive only anonymized participant keys. Every structured
output passes domain validation before persistence. Provider diagnostics are
limited to operational metadata and sanitized error details; prompts and
answer text are not stored in AI run logs.

AI feature entitlements are capability switches, not purchase records. The
current table supports development grants and future billing integration
without coupling product access to a payment SDK. Billing receipts and payment
state belong in a separate boundary.

## Local verification

```sh
npm test
```

## Candidate model evaluation

The candidate evaluator runs the same anonymized service scenarios through
Cloudflare Workers AI, Groq, and the OpenAI Responses API without changing the
deployed provider. It defaults to one smoke case for each of the eight AI
tasks. Models that pass the smoke suite can then run the complete 50-case
suite.

The prompt strategy evaluator compares the deployed Korean prompt with a
candidate prompt through the same production schemas, validators, retry path,
and deterministic fallback. It defaults to one run of `legacy_korean` and
`refined_korean`.

```sh
npm run eval:prompts
```

See [AI candidate model evaluation](../../docs/release/ai-candidate-model-evaluation.md)
for credentials, pacing, commands, and acceptance rules.

## Content safety evaluation

`npm run eval:content-safety` prints an offline plan. Explicit `--live` runs
compare synthetic Korean text through candidate moderation adapters. The new
modules are not connected to publication or deployed Edge Functions.
See [publication boundaries and evaluation setup](../../docs/content-safety-publication-design.md)
for the required server gates, credentials, remaining media coverage, and rollout conditions.

`npm run eval:content-safety-media` prints a network-free preparation plan;
`npm run eval:content-safety-media -- --validate-assets` checks committed synthetic
asset hashes. This preparation command still rejects `--live`. The evaluation-only composition accepts
injected image, extraction, and text ports and never grants publication rights.
See [media evaluation preparation](../../docs/release/content-safety-media-evaluation-plan.md)
and [the Windows/Mac handoff](../../docs/release/content-safety-windows-handoff.md).

2026-10-27: 현재 발화 8개를 모두 커밋했고
별도 실제 평가 도구 `npm run eval:media`를 연결했다. 기본 실행은 외부 요청 없는 계획 출력이다.
`--provider=openai|cloudflare --asr=openai|local`로 모델과 자료·수량·비용을 확인한다.
비용 확인과 승인 이후에만 `--live --approved-plan=<현재 fingerprint>`를 지정한다.
env 파일은 자동으로 읽지 않으며 만료되지 않은 키를 해당 프로세스에만 설정한다.

`npm run eval:media-local`은 Windows OCR·Silero VAD·Vosk로 실제 합성 파일을 검증한다.
Python 모델 환경은 별도 설정하며 현재 ASR 대본 일치가 1/8이므로 품질 미통과 종료 코드 1을 반환한다.
기술 디코딩 통과·자동 품질·사람 청취를 구분한다. 사람 청취는 아직 0/8이다.
설치·실행·모델 해시·예산은 [실제 평가 준비](../../docs/release/content-safety-media-live-readiness.md),
파일별 청취는 [검토표](../../docs/release/content-safety-speech-review.md)를 따른다.

2026-10-29 승인된 OpenAI 미디어 실측은 34회 모두 HTTP 200, 자동 ASR 8/8 CER 0이었다.
안전 분류는 강요 오허용·금지 맥락 오차단 각 2건으로 품질 미통과다.
[실측 보고서](../../docs/release/content-safety-media-evaluation-2026-10-29/README.md)에 결과와 한계를 보존했다.

`npm run eval:policy-review`는 기존 미디어 실측을 네트워크 없이 재검토한다.
현재 오허용 2·오차단 2, 두 대본의 문맥 문제, 사람 청취 8개 대기를 출력하고 종료 코드 1을 반환한다.
`--speech-template`은 기대 대본을 채우지 않은 M4A/WAV 해시 기반 청취 서식을 출력한다.
새 합성 문맥 대조문 12개는 모두 초안이며 실제 모델 호출·제품 분류 정책에는 연결하지 않았다.
[문맥 기준과 자동 검토](../../docs/release/content-safety-context-policy-review-2026-10-29/README.md)를 따른다.

`npm run eval:context`는 Luna/Terra 문맥 분류 후보의 네트워크 없는 계획을 출력한다.
`--candidate=luna|terra|both`로 선택하고 실제 실행에는 별도 승인과 현재 계획 지문이 필요하다.
평가 전용 Responses adapter는 실제 입력 텍스트만 전송하고 schema·근거·실패·요청 한도를 검증한다.
12개 중 초안 10개와 미정 2개를 분리하며 제품 moderation 정책이나 저장 흐름은 변경하지 않는다.
[후보 구현·전송 미리보기·호출 비용](../../docs/release/content-safety-context-candidate-readiness-2026-10-29/README.md)을 따른다.

2026-10-30 승인된 문맥 후보 평가 24회는 모두 HTTP 200이었다. Luna/Terra 각각 초안 10/10 일치,
미정 2개 unavailable이며 제품 게시 권한은 부여하지 않는다. 이번에는 합성 텍스트만 전송했다.
[실측 결과와 한계](../../docs/release/content-safety-context-evaluation-2026-10-30/README.md)에
기존 오류 비교·관측 토큰·비용 추정과 후속 범위를 기록했다. 추가 호출은 별도 승인 대상이다.

`npm run eval:context-expansion`은 피해 진술·인용 처리 제안 v2와 추가 합성 문장 28개를 오프라인으로 검토한다.
`--review-template`은 답변 없는 해시 기반 라벨 검토 서식, `--review=파일`은 사람의 검토 기록을 읽는다.
사람 검토·독립성·모델 품질·게시 권한은 별개이며 기본 출력 성공을 운영 준비 완료로 취급하지 않는다.
`--live`와 키 로드는 지원하지 않고 기존 v1 실측/승인 계획도 보존한다.
[공개 사례 근거·새 표본·검토 절차](../../docs/release/content-safety-context-expansion-2026-10-30/README.md)를 따른다.

`npm run eval:context-expansion-live`는 v2/28문장용 어댑터와 별도 호출 계획을 연결한다.
기본은 네트워크 0건인 계획 출력이다. `--candidate=luna|terra|both`별 최대 28/56회이며,
실제 비용·자료 확인 뒤에만 `--live --approved-plan=<새 지문>`을 사용한다. 기존 v1 승인으로 실행할 수 없다.
초안 라벨 24개와 정답 미정 4개를 분리하며 오류 시 재시도 없이 전체를 중단한다.
[모델·전송 미리보기·비용·보관 조건](../../docs/release/content-safety-context-v2-readiness-2026-10-30/README.md)을 따른다.
