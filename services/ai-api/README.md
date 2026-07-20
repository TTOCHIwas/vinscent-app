# Vinscent AI API

This service owns the model-independent learning boundary for Vinscent.

The current foundation intentionally does not select an LLM provider. Model
adapters must implement `LearningModelPort`, receive only anonymized participant
keys, and return outputs that pass the domain validators before persistence.

The database remains authoritative for consent, job claims, memory confirmation,
question recommendations, and question assignment. A worker must re-check
consent immediately before reading completed answers and before persisting a
result.

## Local verification

```sh
npm test
```
