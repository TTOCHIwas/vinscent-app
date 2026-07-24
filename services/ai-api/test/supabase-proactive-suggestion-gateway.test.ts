import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ProactiveSuggestionContextError,
} from '../src/application/generate-proactive-suggestion.ts';
import {
  SupabaseAccessTokenAuthenticator,
  SupabaseProactiveSuggestionContextSource,
} from '../src/infrastructure/supabase-proactive-suggestion-gateway.ts';

test('Supabase proactive gateway authenticates and parses context', async () => {
  const rpcCalls: unknown[] = [];
  const client = {
    auth: {
      async getUser(token: string) {
        assert.equal(token, 'access-token');
        return {
          data: { user: { id: 'user-1' } },
          error: null,
        };
      },
    },
    async rpc(name: string, args: unknown) {
      rpcCalls.push({ name, args });
      return {
        data: {
          local_date: '2026-07-24',
          local_hour: 18,
          timezone: 'Asia/Seoul',
          has_card_today: false,
          confirmed_memories: [],
          recent_completed_questions: [],
        },
        error: null,
      };
    },
  };

  const authenticator = new SupabaseAccessTokenAuthenticator(client);
  const contextSource = new SupabaseProactiveSuggestionContextSource(client);

  assert.equal(await authenticator.authenticate('access-token'), 'user-1');
  const context = await contextSource.loadForUser('user-1');
  assert.equal(context.localDate, '2026-07-24');
  assert.equal(context.timezone, 'Asia/Seoul');
  assert.deepEqual(rpcCalls, [{
    name: 'get_ai_proactive_suggestion_context',
    args: { requested_user_id: 'user-1' },
  }]);
});

test('Supabase proactive gateway maps only the known readiness error', async () => {
  const client = {
    auth: {
      async getUser() {
        return { data: { user: null }, error: null };
      },
    },
    async rpc() {
      return {
        data: null,
        error: {
          message: 'ai_personalization_not_ready',
          details: 'private database detail',
        },
      };
    },
  };
  const contextSource = new SupabaseProactiveSuggestionContextSource(client);

  await assert.rejects(
    () => contextSource.loadForUser('user-1'),
    (error: unknown) => {
      assert.ok(error instanceof ProactiveSuggestionContextError);
      assert.equal(error.code, 'ai_personalization_not_ready');
      assert.equal(error.message.includes('private database detail'), false);
      return true;
    },
  );
});
