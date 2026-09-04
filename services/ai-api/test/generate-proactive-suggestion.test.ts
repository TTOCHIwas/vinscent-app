import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  CuratedProactiveSuggestionSelectionContext,
} from '../src/application/curated-proactive-suggestion-selector.ts';
import {
  GenerateProactiveSuggestionUseCase,
  type ProactiveSuggestionBaseContext,
  type ProactiveSuggestionContextSource,
} from '../src/application/generate-proactive-suggestion.ts';
import type {
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

test('proactive suggestion selects reviewed copy with the server context date', async () => {
  const contextSource = sourceWith(baseContext);
  const selector = selectorReturning({
    text: '오늘 마음에 남은 순간 하나를 사진이나 그림으로 남겨볼까?',
    kind: 'card_idea',
  });
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource,
    quota: quotaAlwaysAllows(),
    selector,
    weatherClient: null,
    now: () => new Date('2026-07-24T10:00:00.000Z'),
    generateId: () => 'suggestion-1',
  });

  const result = await useCase.execute({
    userId: 'user-1',
    coordinates: null,
  });

  assert.equal(result.suggestionId, 'suggestion-1');
  assert.equal(result.contextDate, '2026-07-24');
  assert.equal(result.generatedAt, '2026-07-24T10:00:00.000Z');
  assert.equal(result.validUntil, '2026-07-24T13:00:00.000Z');
  assert.equal(result.hasCardToday, false);
  assert.deepEqual(selector.contexts, [{
    userId: 'user-1',
    localDate: '2026-07-24',
    localHour: 23,
    hasCardToday: false,
    recordingAvailable: true,
    weather: null,
  }]);
  assert.deepEqual(contextSource.userIds, ['user-1']);
});

test('proactive suggestion treats weather failure as optional context', async () => {
  const selector = selectorReturning({
    text: '오늘 있었던 일 하나 먼저 꺼내 얘기해볼까?',
    kind: 'date_idea',
  });
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    selector,
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
  assert.equal(selector.contexts[0]?.weather, null);
});

test('proactive suggestion forwards available weather to the selector', async () => {
  const selector = selectorReturning({
    text: '곧 노을 질 시간인데 하늘빛 한 장 남겨볼까?',
    kind: 'sunset_card',
  });
  const weather = {
    condition: 'clear' as const,
    apparentTemperatureC: 22,
    precipitationPossible: false,
    nearSunset: true,
    sunsetLocalTime: '19:42',
  };
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    selector,
    weatherClient: {
      async fetchContext(request) {
        assert.equal(request.latitude, 37.5);
        assert.equal(request.longitude, 127);
        assert.equal(request.localDate, '2026-07-24');
        assert.equal(request.timezone, 'Asia/Seoul');
        return weather;
      },
    },
    now: () => new Date('2026-07-24T09:00:00.000Z'),
  });

  const result = await useCase.execute({
    userId: 'user-1',
    coordinates: { latitude: 37.5, longitude: 127 },
  });

  assert.equal(result.kind, 'sunset_card');
  assert.equal(selector.contexts[0]?.weather, weather);
  assert.equal(result.validUntil, '2026-07-24T09:45:00.000Z');
});

test('proactive suggestion clamps its lifetime to the server context date', async () => {
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: quotaAlwaysAllows(),
    selector: selectorReturning({
      text: '오늘 마음에 남은 순간 하나를 사진이나 그림으로 남겨볼까?',
      kind: 'card_idea',
    }),
    weatherClient: null,
    now: () => new Date('2026-07-24T14:55:00.000Z'),
  });

  const result = await useCase.execute({
    userId: 'user-1',
    coordinates: null,
  });

  assert.equal(result.validUntil, '2026-07-24T14:59:00.000Z');
});

test('proactive suggestion claims one daily slot per selection', async () => {
  let quotaClaimCount = 0;
  const selector = selectorReturning({
    text: '사진첩에서 예전 사진 하나 골라 같이 다시 볼까?',
    kind: 'date_idea',
  });
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: {
      async claimGeneration(userId, contextDate) {
        assert.equal(userId, 'user-1');
        assert.equal(contextDate, '2026-07-24');
        quotaClaimCount += 1;
        return true;
      },
    },
    selector,
    weatherClient: null,
  });

  await useCase.execute({ userId: 'user-1', coordinates: null });

  assert.equal(quotaClaimCount, 1);
  assert.equal(selector.contexts.length, 1);
});

test('proactive suggestion does not call providers after the daily limit', async () => {
  const selector = selectorReturning({
    text: '오늘 있었던 일 하나 먼저 꺼내 얘기해볼까?',
    kind: 'date_idea',
  });
  let weatherCallCount = 0;
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith(baseContext),
    quota: {
      async claimGeneration() {
        return false;
      },
    },
    selector,
    weatherClient: {
      async fetchContext() {
        weatherCallCount += 1;
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
  assert.equal(selector.contexts.length, 0);
  assert.equal(weatherCallCount, 0);
});

test('proactive suggestion uses the curated selector by default', async () => {
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource: sourceWith({ ...baseContext, hasCardToday: true }),
    quota: quotaAlwaysAllows(),
    weatherClient: null,
    now: () => new Date('2026-07-24T10:00:00.000Z'),
  });

  const result = await useCase.execute({
    userId: 'user-1',
    coordinates: null,
  });

  assert.equal(result.kind, 'date_idea');
  assert.ok(result.text.length > 0);
});

test('proactive suggestion rejects invalid coordinates before loading context', async () => {
  const contextSource = sourceWith(baseContext);
  const useCase = new GenerateProactiveSuggestionUseCase({
    contextSource,
    quota: quotaAlwaysAllows(),
    weatherClient: null,
  });

  await assert.rejects(
    () => useCase.execute({
      userId: 'user-1',
      coordinates: { latitude: 91, longitude: 127 },
    }),
    /invalid proactive suggestion coordinates/,
  );
  assert.deepEqual(contextSource.userIds, []);
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

function selectorReturning(candidate: ProactiveSuggestionCandidate) {
  return {
    contexts: [] as CuratedProactiveSuggestionSelectionContext[],
    select(context: CuratedProactiveSuggestionSelectionContext) {
      this.contexts.push(context);
      return candidate;
    },
  };
}
