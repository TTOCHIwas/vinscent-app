import {
  ProactiveSuggestionContextError,
  type ProactiveSuggestionBaseContext,
  type ProactiveSuggestionContextSource,
  type ProactiveSuggestionQuota,
} from '../application/generate-proactive-suggestion.ts';
import {
  parseProactiveSuggestionBaseContext,
} from './personalization-context-parser.ts';

interface SupabaseUserResult {
  data: {
    user: { id: string } | null;
  };
  error: unknown;
}

interface SupabaseRpcResult {
  data: unknown;
  error: unknown;
}

interface SupabaseAuthClient {
  auth: {
    getUser(accessToken: string): Promise<SupabaseUserResult>;
  };
}

interface SupabaseRpcClient {
  rpc(
    name: string,
    args: Record<string, unknown>,
  ): PromiseLike<SupabaseRpcResult>;
}

export class SupabaseAccessTokenAuthenticator {
  readonly #client: SupabaseAuthClient;

  constructor(client: SupabaseAuthClient) {
    this.#client = client;
  }

  async authenticate(accessToken: string): Promise<string | null> {
    const { data, error } = await this.#client.auth.getUser(accessToken);
    if (error !== null || data.user === null) {
      return null;
    }
    const userId = data.user.id.trim();
    return userId.length === 0 ? null : userId;
  }
}

export class SupabaseProactiveSuggestionContextSource
  implements ProactiveSuggestionContextSource {
  readonly #client: SupabaseRpcClient;

  constructor(client: SupabaseRpcClient) {
    this.#client = client;
  }

  async loadForUser(userId: string): Promise<ProactiveSuggestionBaseContext> {
    const { data, error } = await this.#client.rpc(
      'get_ai_proactive_suggestion_context',
      { requested_user_id: userId },
    );
    if (error !== null) {
      throw contextError(error);
    }

    try {
      return parseProactiveSuggestionBaseContext(data);
    } catch (error) {
      throw new ProactiveSuggestionContextError(
        'ai_suggestion_context_unavailable',
        error,
      );
    }
  }
}

export class SupabaseProactiveSuggestionQuota
  implements ProactiveSuggestionQuota {
  readonly #client: SupabaseRpcClient;

  constructor(client: SupabaseRpcClient) {
    this.#client = client;
  }

  async claimGeneration(userId: string, contextDate: string): Promise<boolean> {
    const { data, error } = await this.#client.rpc(
      'claim_ai_proactive_suggestion_generation',
      {
        requested_user_id: userId,
        requested_context_date: contextDate,
      },
    );
    if (error !== null || typeof data !== 'boolean') {
      throw new ProactiveSuggestionContextError(
        'ai_suggestion_context_unavailable',
        error,
      );
    }
    return data;
  }
}

function contextError(error: unknown): ProactiveSuggestionContextError {
  const message = typeof error === 'object' && error !== null
    ? (error as Record<string, unknown>).message
    : null;
  return new ProactiveSuggestionContextError(
    message === 'ai_personalization_not_ready'
      ? 'ai_personalization_not_ready'
      : 'ai_suggestion_context_unavailable',
    error,
  );
}
