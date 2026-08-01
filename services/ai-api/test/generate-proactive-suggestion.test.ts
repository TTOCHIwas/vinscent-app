import assert from 'node:assert/strict';
import test from 'node:test';

import {
  GenerateProactiveSuggestionUseCase,
  type ProactiveSuggestionBaseContext,
  type ProactiveSuggestionContextSource,
} from '../src/application/generate-proactive-suggestion.ts';
import { LearningModelError } from '../src/application/learning-model-port.ts';
import type {
  ProactiveSuggestionContext,
  ProactiveSuggestionCandidate,
} from '../src/domain/learning-contract.ts';
const baseContext: ProactiveSuggestionBaseContext = {
  localDate: '2026-07-24',
  localHour: 23,
  timezone: 'Asia/Seoul',
  hasCardToday: false,
  confirmedMemories: [],
  recentCompletedQuestions: [],
};

test('proactive suggestion uses the server context date and clamps its lifetime', async () => {
  const seenContexts: ProactiveSuggestionContext[] = [];
  const contextSource = sourceWith(baseContext);
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource,
    quota: quotaAlwaysAllows(),
    model: {
      async generateProactiveSuggestion(context) {
        seenContexts.push(context);
        return modelResult({
          text: '가까운 곳을 천천히 걸으며 둘이 본 장면을 사진으로 남기면 좋겠다',
          kind: 'card_idea',
        });
      },
    },
    weatherClient: null,
    now: () => new Date('2026-07-24T14:55:00.000Z'),
    generateId: () => 'suggestion-1',
  });

  const result = await useCase.execute({
    userId: 'user-1',
    coordinates: null,
  });

  assert.equal(result.suggestionId, 'suggestion-1');
  assert.equal(result.contextDate, '2026-07-24');
  assert.equal(result.generatedAt, '2026-07-24T14:55:00.000Z');
  assert.equal(result.validUntil, '2026-07-24T14:59:00.000Z');
  assert.equal(result.hasCardToday, false);
  assert.equal(seenContexts[0]?.localDate, '2026-07-24');
  assert.equal(contextSource.userIds[0], 'user-1');
});

test('proactive suggestion treats weather failure as optional context', async () => {
  const seenContexts: ProactiveSuggestionContext[] = [];
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    model: {
      async generateProactiveSuggestion(context) {
        seenContexts.push(context);
        return modelResult({
          text: '오늘은 둘이 좋아하는 간식을 하나 골라 천천히 나눠 먹으며 쉬면 좋겠다',
          kind: 'date_idea',
        });
      },
    },
    weatherClient: {
      async fetchContext() {
        throw new Error('private weather provider detail');
      },
    },
    now: () => new Date('2026-07-24T10:00:00.000Z'),
    generateId: () => 'suggestion-2',
  });

  const result = await useCase.execute({
    userId: 'user-1',
    coordinates: { latitude: 37.5, longitude: 127 },
  });

  assert.equal(result.suggestionId, 'suggestion-2');
  assert.equal(seenContexts[0]?.weather, null);
});

test('proactive suggestion retries one contract-invalid model response', async () => {
  const rejectedOptions: unknown[] = [];
  let quotaClaimCount = 0;
  const outputs: ProactiveSuggestionCandidate[] = [
    {
      text: '오늘은 산책해봐',
      kind: 'date_idea',
    },
    {
      text: '오늘은 가까운 곳을 천천히 걸으며 둘이 느긋하게 쉬는 건 어때?',
      kind: 'date_idea',
    },
  ];
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: {
      async claimGeneration() {
        quotaClaimCount += 1;
        return true;
      },
    },
    model: {
      async generateProactiveSuggestion(_context, options) {
        rejectedOptions.push(options);
        return modelResult(outputs.shift()!);
      },
    },
    weatherClient: null,
    now: () => new Date('2026-07-24T10:00:00.000Z'),
    generateId: () => 'suggestion-retried',
  });

  const result = await useCase.execute({
    userId: 'user-1',
    coordinates: null,
  });

  assert.equal(result.suggestionId, 'suggestion-retried');
  assert.deepEqual(rejectedOptions, [
    { rejectedText: null, rejectionCode: null },
    { rejectedText: '오늘은 산책해봐', rejectionCode: 'too_short' },
  ]);
  assert.equal(quotaClaimCount, 2);
});

test('proactive retry does not echo foreign-script output', async () => {
  const rejectedOptions: unknown[] = [];
  let modelCallCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    model: {
      async generateProactiveSuggestion(_context, options) {
        rejectedOptions.push(options);
        modelCallCount += 1;
        if (modelCallCount === 1) {
          return modelResult({
            text: '오늘気分에 맞는 간식을 하나 골라 둘이 천천히 나눠 먹으면 좋겠다',
            kind: 'date_idea',
          });
        }
        return modelResult({
          text: '오늘 기분에 맞는 간식을 하나 골라 둘이 천천히 나눠 먹으면 좋겠다',
          kind: 'date_idea',
        });
      },
    },
    weatherClient: null,
  });

  const result = await useCase.execute({ userId: 'user-1', coordinates: null });

  assert.equal(result.kind, 'date_idea');
  assert.deepEqual(rejectedOptions, [
    { rejectedText: null, rejectionCode: null },
    { rejectedText: null, rejectionCode: 'foreign_script' },
  ]);
});

test('proactive suggestion does not retry without another model allowance', async () => {
  let quotaClaimCount = 0;
  let modelCallCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: {
      async claimGeneration() {
        quotaClaimCount += 1;
        return quotaClaimCount === 1;
      },
    },
    model: {
      async generateProactiveSuggestion() {
        modelCallCount += 1;
        return modelResult({
          text: '오늘은 산책해봐',
          kind: 'date_idea',
        });
      },
    },
    weatherClient: null,
  });

  await assert.rejects(
    () => useCase.execute({ userId: 'user-1', coordinates: null }),
    (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.equal(error.message, 'ai_proactive_daily_limit_reached');
      return true;
    },
  );
  assert.equal(quotaClaimCount, 2);
  assert.equal(modelCallCount, 1);
});

test('proactive suggestion falls back after two contract-invalid responses', async () => {
  let generationCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    model: {
      async generateProactiveSuggestion() {
        generationCount += 1;
        return modelResult({
          text: '오늘은 산책해봐',
          kind: 'date_idea',
        });
      },
    },
    weatherClient: null,
  });

  const result = await useCase.execute({ userId: 'user-1', coordinates: null });

  assert.equal(generationCount, 2);
  assert.equal(result.kind, 'card_idea');
  assert.equal(
    result.text,
    '오늘 함께한 작은 장면 하나를 사진이나 카드로 남겨도 예쁘겠다',
  );
});

test('proactive suggestion retries one structurally invalid model response', async () => {
  const seenOptions: unknown[] = [];
  let quotaClaimCount = 0;
  let modelCallCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: {
      async claimGeneration() {
        quotaClaimCount += 1;
        return true;
      },
    },
    model: {
      async generateProactiveSuggestion(_context, options) {
        seenOptions.push(options);
        modelCallCount += 1;
        if (modelCallCount === 1) {
          throw new LearningModelError({
            code: 'model_invalid_output',
            retryable: false,
          });
        }
        return modelResult({
          text: '오늘은 둘이 좋아하는 간식을 하나 골라 천천히 나눠 먹으면 좋겠다',
          kind: 'date_idea',
        });
      },
    },
    weatherClient: null,
  });

  const result = await useCase.execute({ userId: 'user-1', coordinates: null });

  assert.equal(result.kind, 'date_idea');
  assert.equal(modelCallCount, 2);
  assert.equal(quotaClaimCount, 2);
  assert.deepEqual(seenOptions, [
    { rejectedText: null, rejectionCode: null },
    { rejectedText: null, rejectionCode: 'invalid_structure' },
  ]);
});

test('proactive suggestion falls back after two structurally invalid responses', async () => {
  let modelCallCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    model: {
      async generateProactiveSuggestion() {
        modelCallCount += 1;
        throw new LearningModelError({
          code: 'model_invalid_output',
          retryable: false,
        });
      },
    },
    weatherClient: null,
  });

  const result = await useCase.execute({ userId: 'user-1', coordinates: null });

  assert.equal(modelCallCount, 2);
  assert.equal(result.kind, 'card_idea');
  assert.equal(
    result.text,
    '오늘 함께한 작은 장면 하나를 사진이나 카드로 남겨도 예쁘겠다',
  );
});

test('proactive suggestion preserves non-output model failures', async () => {
  const expectedError = new LearningModelError({
    code: 'model_unavailable',
    retryable: true,
  });
  let modelCallCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    model: {
      async generateProactiveSuggestion() {
        modelCallCount += 1;
        throw expectedError;
      },
    },
    weatherClient: null,
  });

  await assert.rejects(
    () => useCase.execute({ userId: 'user-1', coordinates: null }),
    (error: unknown) => error === expectedError,
  );
  assert.equal(modelCallCount, 1);
});

test('proactive suggestion accepts a natural 29 character response', async () => {
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    model: {
      async generateProactiveSuggestion() {
        return modelResult({
          text: '밖에서 함께 걸으면서 둘만의 시간을 보내는 건 어때?',
          kind: 'date_idea',
        });
      },
    },
    weatherClient: null,
  });

  const result = await useCase.execute({ userId: 'user-1', coordinates: null });

  assert.equal(result.text, '밖에서 함께 걸으면서 둘만의 시간을 보내는 건 어때?');
});

test('proactive suggestion does not call providers after the daily limit', async () => {
  let modelCallCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: {
      async claimGeneration() {
        return false;
      },
    },
    model: {
      async generateProactiveSuggestion() {
        modelCallCount += 1;
        return modelResult({
          text: '오늘은 가까운 곳을 천천히 걸으며 둘이 느긋하게 쉬는 건 어때?',
          kind: 'date_idea',
        });
      },
    },
    weatherClient: {
      async fetchContext() {
        throw new Error('weather must not be called');
      },
    },
  });

  await assert.rejects(
    () => useCase.execute({ userId: 'user-1', coordinates: null }),
    (error: unknown) => {
      assert.ok(error instanceof Error);
      assert.equal(error.message, 'ai_proactive_daily_limit_reached');
      return true;
    },
  );
  assert.equal(modelCallCount, 0);
});

function sourceWith(
  context: ProactiveSuggestionBaseContext,
): ProactiveSuggestionContextSource & { userIds: string[] } {
  return {
    userIds: [],
    async loadForUser(userId) {
      this.userIds.push(userId);
      return context;
    },
  };
}

function quotaAlwaysAllows() {
  return {
    async claimGeneration() {
      return true;
    },
  };
}

function modelResult(value: ProactiveSuggestionCandidate) {
  return {
    value,
    usage: {
      inputTokenCount: 10,
      outputTokenCount: 5,
      latencyMs: 20,
    },
  };
}
