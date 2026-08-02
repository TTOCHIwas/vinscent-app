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
tasks. Models that pass the smoke suite can then run the complete 47-case
suite.

See [AI candidate model evaluation](../../docs/release/ai-candidate-model-evaluation.md)
for credentials, pacing, commands, and acceptance rules.
