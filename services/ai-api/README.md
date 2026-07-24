# Vinscent AI API

This service owns the model-independent learning boundary for Vinscent.

`LearningModelPort` keeps application and domain code independent from a model
provider. The deployed `process-ai-learning-jobs` Edge Function currently
connects that port to Gemini through `GeminiLearningModel`. Replacing the
provider must not change the job repository or domain contracts. Provider
adapters translate their native failures into `LearningModelError` before an
error reaches the application layer.

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
