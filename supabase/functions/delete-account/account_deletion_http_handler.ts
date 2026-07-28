import { jsonResponse } from '../_shared/webhook.ts';
import type {
  AccountDeletionResult,
  AccountDeletionService,
} from './account_deletion_service.ts';

export type AccountIdentity = {
  userId: string;
};

export interface AccountDeletionAuthenticator {
  authenticate(accessToken: string): Promise<AccountIdentity | null>;
}

export type AccountDeletionHttpHandlerDependencies = {
  authenticator: AccountDeletionAuthenticator;
  deletionService: Pick<AccountDeletionService, 'deleteAccount'>;
  onError?: (error: unknown) => void;
};

export function createAccountDeletionHttpHandler(
  dependencies: AccountDeletionHttpHandlerDependencies,
) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') {
      return new Response(
        JSON.stringify({ error: 'method_not_allowed' }),
        {
          status: 405,
          headers: {
            'content-type': 'application/json',
            allow: 'POST',
          },
        },
      );
    }

    const accessToken = bearerTokenFrom(request);
    if (!accessToken) {
      return jsonResponse({ error: 'unauthorized' }, 401);
    }

    try {
      const identity = await dependencies.authenticator.authenticate(
        accessToken,
      );
      if (!identity) {
        return jsonResponse({ error: 'unauthorized' }, 401);
      }

      const result = await dependencies.deletionService.deleteAccount(
        identity.userId,
      );
      return deletionResponse(result);
    } catch (error) {
      dependencies.onError?.(error);
      return jsonResponse({ error: 'account_deletion_failed' }, 500);
    }
  };
}

function bearerTokenFrom(request: Request): string | null {
  const authorization = request.headers.get('authorization')?.trim();
  const match = authorization?.match(/^Bearer\s+(.+)$/i);
  const token = match?.[1]?.trim();
  return token ? token : null;
}

function deletionResponse(result: AccountDeletionResult) {
  return jsonResponse({
    status: 'deleted',
    deletedCoupleCount: result.deletedCoupleCount,
  });
}
