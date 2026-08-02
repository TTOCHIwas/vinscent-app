export type DiscordWebhookFailureKind =
  | 'unavailable'
  | 'rate_limited'
  | 'rejected';

type DiscordWebhookClientOptions = {
  endpoint: string;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
};

type DiscordWebhookRequestErrorOptions = {
  retryAfterSeconds?: number;
};

export class DiscordWebhookRequestError extends Error {
  readonly kind: DiscordWebhookFailureKind;
  readonly retryAfterSeconds?: number;

  constructor(
    kind: DiscordWebhookFailureKind,
    options: DiscordWebhookRequestErrorOptions = {},
  ) {
    super(`discord_webhook_${kind}`);
    this.name = 'DiscordWebhookRequestError';
    this.kind = kind;
    this.retryAfterSeconds = options.retryAfterSeconds;
  }
}

export class DiscordWebhookClient {
  readonly #endpoint: URL;
  readonly #timeoutMs: number;
  readonly #fetch: typeof fetch;

  constructor(options: DiscordWebhookClientOptions) {
    this.#endpoint = parseDiscordWebhookEndpoint(options.endpoint);
    this.#timeoutMs = options.timeoutMs ?? 10_000;
    if (
      !Number.isInteger(this.#timeoutMs) ||
      this.#timeoutMs < 1 ||
      this.#timeoutMs > 30_000
    ) {
      throw new RangeError(
        'Discord webhook timeout must be between 1 and 30000 milliseconds',
      );
    }
    this.#fetch = options.fetchImpl ?? fetch;
  }

  async send(payload: unknown): Promise<void> {
    let response: Response;
    try {
      response = await this.#fetch(this.#endpoint, {
        method: 'POST',
        redirect: 'error',
        headers: {
          'content-type': 'application/json',
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(this.#timeoutMs),
      });
    } catch {
      throw new DiscordWebhookRequestError('unavailable');
    }

    if (response.ok) {
      return;
    }
    if (response.status === 429) {
      throw new DiscordWebhookRequestError('rate_limited', {
        retryAfterSeconds: readRetryAfterSeconds(response),
      });
    }
    if (response.status >= 500) {
      throw new DiscordWebhookRequestError('unavailable');
    }
    throw new DiscordWebhookRequestError('rejected');
  }
}

function parseDiscordWebhookEndpoint(value: string): URL {
  const endpoint = new URL(value);
  if (endpoint.protocol !== 'https:') {
    throw new TypeError('Discord webhook endpoint must use HTTPS');
  }
  if (
    endpoint.hostname !== 'discord.com' &&
    endpoint.hostname !== 'discordapp.com'
  ) {
    throw new TypeError('Discord webhook endpoint host is invalid');
  }
  if (
    !/^\/api(?:\/v\d+)?\/webhooks\/\d+\/[A-Za-z0-9._-]+\/?$/.test(
      endpoint.pathname,
    )
  ) {
    throw new TypeError('Discord webhook endpoint path is invalid');
  }
  endpoint.hostname = 'discord.com';
  endpoint.searchParams.set('wait', 'true');
  return endpoint;
}

function readRetryAfterSeconds(response: Response): number | undefined {
  const value = Number(response.headers.get('retry-after'));
  if (!Number.isFinite(value) || value <= 0) {
    return undefined;
  }
  return Math.min(Math.max(Math.ceil(value), 1), 3600);
}
