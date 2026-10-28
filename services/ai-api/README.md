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
