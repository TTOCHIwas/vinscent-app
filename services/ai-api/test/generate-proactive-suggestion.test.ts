import assert from 'node:assert/strict';
import test from 'node:test';

import {
  GenerateProactiveSuggestionUseCase,
  type ProactiveSuggestionBaseContext,
  type ProactiveSuggestionContextSource,
} from '../src/application/generate-proactive-suggestion.ts';
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
    model: {
      async generateProactiveSuggestion(context) {
        seenContexts.push(context);
        return modelResult({
          text: '날씨가 괜찮아 보이면 가까운 곳을 천천히 걸으며 사진을 남기면 좋겠다',
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
