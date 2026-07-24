import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ProactiveSuggestionContextError,
  type GeneratedProactiveSuggestion,
} from '../src/application/generate-proactive-suggestion.ts';
import {
  createProactiveSuggestionHttpHandler,
} from '../src/presentation/proactive-suggestion-http-handler.ts';

const generatedSuggestion: GeneratedProactiveSuggestion = {
  suggestionId: 'suggestion-1',
  text: '날씨가 괜찮아 보이면 가까운 곳을 천천히 걸으며 사진을 남기면 좋겠다',
  kind: 'card_idea',
  generatedAt: '2026-07-24T10:00:00.000Z',
  validUntil: '2026-07-24T13:00:00.000Z',
  contextDate: '2026-07-24',
  hasCardToday: false,
};

test('proactive handler authenticates the user and forwards valid coordinates', async () => {
  const calls: unknown[] = [];
  const handler = createProactiveSuggestionHttpHandler({
    authenticator: {
      async authenticate(accessToken) {
        assert.equal(accessToken, 'user-token');
        return 'user-1';
      },
    },
    generator: {
      async execute(input) {
        calls.push(input);
        return generatedSuggestion;
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: {
      authorization: 'Bearer user-token',
      'content-type': 'application/json',
    },
    body: JSON.stringify({ latitude: 37.5, longitude: 127 }),
  }));

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    suggestion_id: 'suggestion-1',
    text: generatedSuggestion.text,
    kind: 'card_idea',
    generated_at: '2026-07-24T10:00:00.000Z',
    valid_until: '2026-07-24T13:00:00.000Z',
    context_date: '2026-07-24',
    has_card_today: false,
  });
  assert.deepEqual(calls, [{
    userId: 'user-1',
    coordinates: { latitude: 37.5, longitude: 127 },
  }]);
});

test('proactive handler rejects unauthenticated and malformed requests', async () => {
  const handler = createProactiveSuggestionHttpHandler({
    authenticator: {
      async authenticate() {
        return null;
      },
    },
    generator: {
      async execute() {
        throw new Error('must not execute');
      },
    },
  });

  const unauthorized = await handler(new Request('https://example.test', {
    method: 'POST',
  }));
  assert.equal(unauthorized.status, 401);

  const malformedHandler = createProactiveSuggestionHttpHandler({
    authenticator: {
      async authenticate() {
        return 'user-1';
      },
    },
    generator: {
      async execute() {
        throw new Error('must not execute');
      },
    },
  });
  const malformed = await malformedHandler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer user-token' },
    body: JSON.stringify({ latitude: 91, longitude: 127 }),
  }));
  assert.equal(malformed.status, 400);
  assert.deepEqual(await malformed.json(), { error: 'invalid_request' });
});

test('proactive handler exposes only the safe personalization readiness code', async () => {
  const handler = createProactiveSuggestionHttpHandler({
    authenticator: {
      async authenticate() {
        return 'user-1';
      },
    },
    generator: {
      async execute() {
        throw new ProactiveSuggestionContextError(
          'ai_personalization_not_ready',
        );
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer user-token' },
  }));

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), {
    error: 'ai_personalization_not_ready',
  });
});

test('proactive handler reports the daily generation limit without provider details', async () => {
  const handler = createProactiveSuggestionHttpHandler({
    authenticator: {
      async authenticate() {
        return 'user-1';
      },
    },
    generator: {
      async execute() {
        throw new ProactiveSuggestionContextError(
          'ai_proactive_daily_limit_reached',
        );
      },
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer user-token' },
  }));

  assert.equal(response.status, 429);
  assert.deepEqual(await response.json(), {
    error: 'ai_proactive_daily_limit_reached',
  });
});

test('proactive handler logs a safe context failure code', async () => {
  const logged: unknown[] = [];
  const handler = createProactiveSuggestionHttpHandler({
    authenticator: {
      async authenticate() {
        return 'user-1';
      },
    },
    generator: {
      async execute() {
        throw new ProactiveSuggestionContextError(
          'ai_suggestion_context_unavailable',
          new Error('private database detail'),
        );
      },
    },
    onError(errorType) {
      logged.push(errorType);
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer user-token' },
  }));

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: 'ai_suggestion_context_unavailable',
  });
  assert.deepEqual(logged, ['ai_suggestion_context_unavailable']);
});

test('proactive handler logs only an error type and hides internal failures', async () => {
  const logged: unknown[] = [];
  const handler = createProactiveSuggestionHttpHandler({
    authenticator: {
      async authenticate() {
        return 'user-1';
      },
    },
    generator: {
      async execute() {
        throw new Error('private prompt or provider detail');
      },
    },
    onError(errorType) {
      logged.push(errorType);
    },
  });

  const response = await handler(new Request('https://example.test', {
    method: 'POST',
    headers: { authorization: 'Bearer user-token' },
  }));

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), {
    error: 'ai_suggestion_unavailable',
  });
  assert.deepEqual(logged, ['Error']);
});
