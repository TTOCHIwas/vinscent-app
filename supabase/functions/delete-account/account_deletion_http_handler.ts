import { jsonResponse } from '../_shared/webhook.ts';
import type {
  AccountDeletionResult,
  AccountDeletionService,
} from './account_deletion_service.ts';

export type AccountIdentity = {
  userId: string;
  appleSubject?: string;
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

      const body = await readDeletionRequest(request);
      if (!body) {
        return jsonResponse({ error: 'invalid_request' }, 400);
      }

      const options = identity.appleSubject
        ? {
          appleSubject: identity.appleSubject,
          appleAuthorizationCode: body.appleAuthorizationCode,
        }
        : {};
      const result = await dependencies.deletionService.deleteAccount(
        identity.userId,
        options,
      );
      return deletionResponse(result);
    } catch (error) {
      if (
        error instanceof Error &&
        error.message === 'apple_reauthentication_required'
      ) {
        return jsonResponse(
          { error: 'apple_reauthentication_required' },
          409,
        );
      }
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

async function readDeletionRequest(
  request: Request,
): Promise<{ appleAuthorizationCode?: string } | null> {
  const contentLength = Number(request.headers.get('content-length') ?? 0);
  if (Number.isFinite(contentLength) && contentLength > 8192) {
    return null;
  }

  let rawBody: string;
  try {
    rawBody = await request.text();
  } catch {
    return null;
  }
  if (!rawBody.trim()) {
    return {};
  }
  if (rawBody.length > 8192) {
    return null;
  }

  let payload: unknown;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return null;
  }
  if (
    payload === null ||
    typeof payload !== 'object' ||
    Array.isArray(payload)
  ) {
    return null;
  }

  const authorizationCode = (
    payload as Record<string, unknown>
  ).appleAuthorizationCode;
  if (authorizationCode === undefined) {
    return {};
  }
  if (typeof authorizationCode !== 'string') {
    return null;
  }

  const normalizedCode = authorizationCode.trim();
  if (normalizedCode.length > 4096) {
    return null;
  }
  return normalizedCode
    ? { appleAuthorizationCode: normalizedCode }
    : {};
}

function deletionResponse(result: AccountDeletionResult) {
  return jsonResponse({
    status: 'deleted',
    deletedCoupleCount: result.deletedCoupleCount,
  });
}
