type Fetch = (
  input: RequestInfo | URL,
  init?: RequestInit,
) => Promise<Response>;

type AppleTokenRevokerDependencies = {
  clientId: string;
  createClientSecret: () => Promise<string>;
  fetch: Fetch;
};

type RevokeAuthorizationCodeRequest = {
  authorizationCode: string;
  expectedSubject: string;
};

type AppleTokenResponse = {
  refreshToken: string;
  subject: string;
};

const appleTokenEndpoint = 'https://appleid.apple.com/auth/token';
const appleRevokeEndpoint = 'https://appleid.apple.com/auth/revoke';

export class AppleTokenRevoker {
  readonly #clientId: string;
  readonly #createClientSecret: () => Promise<string>;
  readonly #fetch: Fetch;

  constructor(dependencies: AppleTokenRevokerDependencies) {
    this.#clientId = dependencies.clientId.trim();
    this.#createClientSecret = dependencies.createClientSecret;
    this.#fetch = dependencies.fetch;
  }

  async revokeAuthorizationCode(
    request: RevokeAuthorizationCodeRequest,
  ): Promise<void> {
    const authorizationCode = request.authorizationCode.trim();
    const expectedSubject = request.expectedSubject.trim();
    if (!authorizationCode) {
      throw new Error('apple_authorization_code_required');
    }
    if (!expectedSubject) {
      throw new Error('apple_subject_required');
    }
    if (!this.#clientId) {
      throw new Error('apple_client_id_required');
    }

    const clientSecret = (await this.#createClientSecret()).trim();
    if (!clientSecret) {
      throw new Error('apple_client_secret_required');
    }

    const token = await this.#exchangeAuthorizationCode({
      authorizationCode,
      clientSecret,
    });
    if (token.subject !== expectedSubject) {
      throw new Error('apple_identity_mismatch');
    }

    await this.#revokeRefreshToken({
      clientSecret,
      refreshToken: token.refreshToken,
    });
  }

  async #exchangeAuthorizationCode({
    authorizationCode,
    clientSecret,
  }: {
    authorizationCode: string;
    clientSecret: string;
  }): Promise<AppleTokenResponse> {
    const response = await this.#fetch(appleTokenEndpoint, {
      method: 'POST',
      headers: formHeaders(),
      body: new URLSearchParams({
        client_id: this.#clientId,
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: 'authorization_code',
      }),
    });
    if (!response.ok) {
      throw new Error('apple_token_exchange_failed');
    }

    const payload = await readJsonObject(response);
    const refreshToken = readRequiredString(payload, 'refresh_token');
    const identityToken = readRequiredString(payload, 'id_token');
    if (!refreshToken || !identityToken) {
      throw new Error('apple_token_response_invalid');
    }

    const subject = readJwtSubject(identityToken);
    if (!subject) {
      throw new Error('apple_token_response_invalid');
    }

    return { refreshToken, subject };
  }

  async #revokeRefreshToken({
    clientSecret,
    refreshToken,
  }: {
    clientSecret: string;
    refreshToken: string;
  }): Promise<void> {
    const response = await this.#fetch(appleRevokeEndpoint, {
      method: 'POST',
      headers: formHeaders(),
      body: new URLSearchParams({
        client_id: this.#clientId,
        client_secret: clientSecret,
        token: refreshToken,
        token_type_hint: 'refresh_token',
      }),
    });
    if (!response.ok) {
      throw new Error('apple_token_revocation_failed');
    }
  }
}

function formHeaders(): HeadersInit {
  return {
    'content-type': 'application/x-www-form-urlencoded',
  };
}

async function readJsonObject(
  response: Response,
): Promise<Record<string, unknown>> {
  try {
    const value: unknown = await response.json();
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, unknown>;
    }
  } catch {
    // The caller maps malformed provider output to a stable domain error.
  }
  throw new Error('apple_token_response_invalid');
}

function readRequiredString(
  value: Record<string, unknown>,
  key: string,
): string | null {
  const candidate = value[key];
  if (typeof candidate !== 'string') {
    return null;
  }
  const normalized = candidate.trim();
  return normalized ? normalized : null;
}

function readJwtSubject(token: string): string | null {
  const payloadSegment = token.split('.')[1];
  if (!payloadSegment) {
    return null;
  }

  try {
    const normalized = payloadSegment.replace(/-/g, '+').replace(/_/g, '/');
    const padded = normalized.padEnd(
      normalized.length + ((4 - normalized.length % 4) % 4),
      '=',
    );
    const bytes = Uint8Array.from(atob(padded), (character) =>
      character.charCodeAt(0)
    );
    const payload: unknown = JSON.parse(new TextDecoder().decode(bytes));
    if (payload === null || typeof payload !== 'object') {
      return null;
    }
    const subject = (payload as Record<string, unknown>).sub;
    return typeof subject === 'string' && subject.trim()
      ? subject.trim()
      : null;
  } catch {
    return null;
  }
}
