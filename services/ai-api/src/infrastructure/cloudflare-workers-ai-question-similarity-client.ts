const endpointBase = 'https://api.cloudflare.com/client/v4/accounts';
const model = '@cf/baai/bge-m3';
const accountIdPattern = /^[a-f0-9]{32}$/i;
const defaultTimeoutMs = 30_000;
const maximumContexts = 50;
const maximumQuestionLength = 4_000;

export interface CloudflareWorkersAiQuestionSimilarityClientOptions {
  accountId: string;
  apiToken: string;
  timeoutMs?: number;
  fetcher?: typeof fetch;
}

export class CloudflareWorkersAiQuestionSimilarityClient {
  readonly #apiToken: string;
  readonly #endpoint: string;
  readonly #timeoutMs: number;
  readonly #fetcher: typeof fetch;

  constructor(options: CloudflareWorkersAiQuestionSimilarityClientOptions) {
    const accountId = options.accountId.trim();
    if (!accountIdPattern.test(accountId)) {
      throw new TypeError('invalid Cloudflare account ID');
    }
    const apiToken = options.apiToken.trim();
    if (apiToken.length === 0) {
      throw new TypeError('Cloudflare API token is required');
    }
    const timeoutMs = options.timeoutMs ?? defaultTimeoutMs;
    if (!Number.isInteger(timeoutMs) || timeoutMs <= 0) {
      throw new RangeError('Cloudflare similarity timeout must be positive');
    }

    this.#apiToken = apiToken;
    this.#endpoint = `${endpointBase}/${accountId}/ai/run/${model}`;
    this.#timeoutMs = timeoutMs;
    this.#fetcher = options.fetcher ?? fetch;
  }

  async score(query: string, contexts: readonly string[]): Promise<number[]> {
    const normalizedQuery = requireQuestion(query, 'query');
    if (contexts.length === 0 || contexts.length > maximumContexts) {
      throw new RangeError(
        `Cloudflare similarity contexts must contain 1-${maximumContexts} questions`,
      );
    }
    const normalizedContexts = contexts.map((context) =>
      requireQuestion(context, 'context')
    );
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.#timeoutMs);

    try {
      const response = await this.#fetcher(this.#endpoint, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.#apiToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          query: normalizedQuery,
          contexts: normalizedContexts.map((text) => ({ text })),
          truncate_inputs: false,
        }),
        signal: controller.signal,
      });
      const payload = await readJson(response);
      if (!response.ok || readRecord(payload)?.success !== true) {
        throw new Error('Cloudflare similarity request failed');
      }
      return readScores(payload, normalizedContexts.length);
    } finally {
      clearTimeout(timeout);
    }
  }
}

function requireQuestion(value: string, name: string): string {
  const normalized = value.trim();
  if (
    normalized.length === 0
    || normalized.length > maximumQuestionLength
  ) {
    throw new TypeError(`invalid similarity ${name}`);
  }
  return normalized;
}

async function readJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch (error) {
    throw new Error('invalid similarity response', { cause: error });
  }
}

function readScores(payload: unknown, expectedCount: number): number[] {
  const root = readRecord(payload);
  const result = readRecord(root?.result);
  const response = result?.response;
  if (!Array.isArray(response) || response.length !== expectedCount) {
    throw new Error('invalid similarity response');
  }

  const scores: Array<number | undefined> = Array(expectedCount);
  for (const rawItem of response) {
    const item = readRecord(rawItem);
    const id = item?.id;
    const score = item?.score;
    if (
      !Number.isInteger(id)
      || Number(id) < 0
      || Number(id) >= expectedCount
      || typeof score !== 'number'
      || !Number.isFinite(score)
      || scores[Number(id)] !== undefined
    ) {
      throw new Error('invalid similarity response');
    }
    scores[Number(id)] = score;
  }

  if (scores.some((score) => score === undefined)) {
    throw new Error('invalid similarity response');
  }
  return scores as number[];
}

function readRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
