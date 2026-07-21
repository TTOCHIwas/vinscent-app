import type {
  LearningModelUsage,
} from '../application/learning-model-port.ts';

const defaultEndpointBase =
  'https://generativelanguage.googleapis.com/v1beta/models';
const defaultModel = 'gemini-3.1-flash-lite';
const defaultTimeoutMs = 30_000;
const maximumRetryAfterMs = 86_400_000;
const maximumProviderErrorDetailLength = 500;
const outputValidationDetailPattern = /^[a-z][a-z0-9_.]{0,159}$/;

export interface StructuredGenerationRequest {
  prompt: string;
  schema: Record<string, unknown>;
}

export interface StructuredGenerationResult {
  value: unknown;
  usage: LearningModelUsage;
}

export interface StructuredGenerationClient {
  generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<StructuredGenerationResult>;
}

interface GeminiStructuredGenerationClientOptions {
  apiKey: string;
  model?: string;
  endpoint?: string;
  timeoutMs?: number;
  fetcher?: typeof fetch;
  now?: () => number;
}

export class GeminiProviderError extends Error {
  readonly code: string;
  readonly retryable: boolean;
  readonly status: number | null;
  readonly providerStatus: string | null;
  readonly providerErrorDetail: string | null;
  readonly retryAfterMs: number | null;
  readonly latencyMs: number;

  constructor(params: {
    code: string;
    retryable: boolean;
    status?: number | null;
    providerStatus?: string | null;
    providerErrorDetail?: string | null;
    retryAfterMs?: number | null;
    latencyMs?: number;
    cause?: unknown;
  }) {
    super(params.code, { cause: params.cause });
    this.name = 'GeminiProviderError';
    this.code = params.code;
    this.retryable = params.retryable;
    this.status = params.status ?? null;
    this.providerStatus = params.providerStatus ?? null;
    this.providerErrorDetail = params.providerErrorDetail ?? null;
    this.retryAfterMs = params.retryAfterMs ?? null;
    this.latencyMs = params.latencyMs ?? 0;
  }
}

export class GeminiOutputError extends Error {
  readonly code = 'gemini_invalid_output';
  readonly retryable = false;
  readonly latencyMs: number;
  readonly validationDetail: string | null;

  constructor(
    cause?: unknown,
    latencyMs = 0,
    validationDetail: string | null = null,
  ) {
    super('gemini_invalid_output', { cause });
    this.name = 'GeminiOutputError';
    this.latencyMs = latencyMs;
    this.validationDetail = validationDetail !== null
      && outputValidationDetailPattern.test(validationDetail)
      ? validationDetail
      : null;
  }
}

export class GeminiStructuredGenerationClient
  implements StructuredGenerationClient {
  readonly #apiKey: string;
  readonly #model: string;
  readonly #endpoint: string;
  readonly #timeoutMs: number;
  readonly #fetcher: typeof fetch;
  readonly #now: () => number;

  constructor(options: GeminiStructuredGenerationClientOptions) {
    if (options.apiKey.trim().length === 0) {
      throw new TypeError('Gemini API key is required');
    }

    this.#apiKey = options.apiKey;
    this.#model = generateContentModelName(
      requireConfigValue(options.model ?? defaultModel, 'model'),
    );
    this.#endpoint = requireConfigValue(
      options.endpoint ?? generateContentEndpoint(this.#model),
      'endpoint',
    );
    this.#timeoutMs = options.timeoutMs ?? defaultTimeoutMs;
    if (!Number.isInteger(this.#timeoutMs) || this.#timeoutMs <= 0) {
      throw new RangeError('Gemini timeout must be a positive integer');
    }
    this.#fetcher = options.fetcher ?? fetch;
    this.#now = options.now ?? Date.now;
  }

  async generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<StructuredGenerationResult> {
    if (request.prompt.trim().length === 0) {
      throw new TypeError('Gemini prompt is required');
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.#timeoutMs);
    const startedAt = this.#now();

    try {
      const response = await this.#fetcher(this.#endpoint, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': this.#apiKey,
        },
        body: JSON.stringify({
          contents: [
            {
              role: 'user',
              parts: [{ text: request.prompt }],
            },
          ],
          generationConfig: {
            temperature: 0.2,
            responseMimeType: 'application/json',
            responseJsonSchema: request.schema,
          },
        }),
        signal: controller.signal,
      });

      const completedAt = this.#now();
      const latencyMs = Math.max(0, completedAt - startedAt);
      const payload = await readJsonResponse(response, latencyMs);
      if (!response.ok) {
        throw providerErrorForResponse(
          response,
          payload,
          completedAt,
          latencyMs,
        );
      }

      const outputText = readOutputText(payload, latencyMs);
      let value: unknown;
      try {
        value = JSON.parse(outputText);
      } catch (error) {
        throw new GeminiOutputError(error, latencyMs);
      }

      const usage = readUsage(payload);
      return {
        value,
        usage: {
          inputTokenCount: usage.inputTokenCount,
          outputTokenCount: usage.outputTokenCount,
          latencyMs,
        },
      };
    } catch (error) {
      if (error instanceof GeminiProviderError || error instanceof GeminiOutputError) {
        throw error;
      }

      if (isAbortError(error)) {
        throw new GeminiProviderError({
          code: 'gemini_timeout',
          retryable: true,
          latencyMs: Math.max(0, this.#now() - startedAt),
          cause: error,
        });
      }

      throw new GeminiProviderError({
        code: 'gemini_network_error',
        retryable: true,
        latencyMs: Math.max(0, this.#now() - startedAt),
        cause: error,
      });
    } finally {
      clearTimeout(timeout);
    }
  }
}

function requireConfigValue(value: string, name: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`Gemini ${name} is required`);
  }
  return normalized;
}

function generateContentModelName(model: string): string {
  const normalized = model.startsWith('models/')
    ? model.slice('models/'.length)
    : model;
  if (!/^[a-zA-Z0-9._-]+$/.test(normalized)) {
    throw new TypeError('Gemini model has an invalid format');
  }
  return normalized;
}

function generateContentEndpoint(model: string): string {
  return `${defaultEndpointBase}/${model}:generateContent`;
}

async function readJsonResponse(
  response: Response,
  latencyMs: number,
): Promise<unknown> {
  try {
    return await response.json();
  } catch (error) {
    if (response.ok) {
      throw new GeminiOutputError(error, latencyMs);
    }
    return null;
  }
}

function readOutputText(payload: unknown, latencyMs: number): string {
  const record = asRecord(payload);
  const candidates = Array.isArray(record?.candidates)
    ? record.candidates
    : [];
  const text = candidates.flatMap((candidate) => {
      const parts = asRecord(asRecord(candidate)?.content)?.parts;
      return Array.isArray(parts) ? parts : [];
    })
    .map((part) => asRecord(part)?.text)
    .filter((part): part is string => typeof part === 'string')
    .join('');

  if (text.length === 0) {
    throw new GeminiOutputError(undefined, latencyMs);
  }
  return text;
}

function readUsage(payload: unknown): {
  inputTokenCount: number | null;
  outputTokenCount: number | null;
} {
  const record = asRecord(payload);
  const usage = asRecord(record?.usageMetadata);
  return {
    inputTokenCount: readNonNegativeInteger(
      usage?.promptTokenCount,
    ),
    outputTokenCount: readNonNegativeInteger(
      usage?.candidatesTokenCount,
    ),
  };
}

function readNonNegativeInteger(value: unknown): number | null {
  return Number.isInteger(value) && Number(value) >= 0 ? Number(value) : null;
}

function providerErrorForResponse(
  response: Response,
  payload: unknown,
  completedAt: number,
  latencyMs: number,
): GeminiProviderError {
  const status = response.status;
  const diagnostics = {
    status,
    providerStatus: readProviderStatus(payload),
    providerErrorDetail: readProviderErrorDetail(payload),
    retryAfterMs: readRetryAfterMs(response, payload, completedAt),
    latencyMs,
  };

  if (status === 429) {
    return new GeminiProviderError({
      code: 'gemini_rate_limited',
      retryable: true,
      ...diagnostics,
    });
  }
  if (status === 408 || status === 409 || status >= 500) {
    return new GeminiProviderError({
      code: 'gemini_provider_unavailable',
      retryable: true,
      ...diagnostics,
    });
  }
  if (status === 400) {
    return new GeminiProviderError({
      code: 'gemini_invalid_request',
      retryable: false,
      ...diagnostics,
    });
  }
  if (status === 401 || status === 403) {
    return new GeminiProviderError({
      code: 'gemini_auth_failed',
      retryable: false,
      ...diagnostics,
    });
  }
  if (status === 404) {
    return new GeminiProviderError({
      code: 'gemini_model_not_found',
      retryable: false,
      ...diagnostics,
    });
  }
  return new GeminiProviderError({
    code: 'gemini_request_failed',
    retryable: false,
    ...diagnostics,
  });
}

function readProviderStatus(payload: unknown): string | null {
  const error = asRecord(asRecord(payload)?.error);
  const status = error?.status;
  if (
    typeof status !== 'string'
    || !/^[A-Z][A-Z0-9_]{0,99}$/.test(status)
  ) {
    return null;
  }
  return status;
}

function readProviderErrorDetail(payload: unknown): string | null {
  const error = asRecord(asRecord(payload)?.error);
  if (typeof error?.message !== 'string') {
    return null;
  }

  const normalized = error.message
    .replace(/\bAIza[0-9A-Za-z_-]{12,}\b/g, '[REDACTED]')
    .replace(/\bBearer\s+[0-9A-Za-z._~-]+/gi, 'Bearer [REDACTED]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[REDACTED]')
    .replace(/[\u0000-\u001F\u007F]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (normalized.length === 0) {
    return null;
  }
  return normalized.slice(0, maximumProviderErrorDetailLength);
}

function readRetryAfterMs(
  response: Response,
  payload: unknown,
  completedAt: number,
): number | null {
  const candidates = [
    parseRetryAfterHeader(response.headers.get('retry-after'), completedAt),
    parseRetryInfo(payload),
  ].filter((value): value is number => value !== null);

  if (candidates.length === 0) {
    return null;
  }
  return Math.min(maximumRetryAfterMs, Math.max(...candidates));
}

function parseRetryAfterHeader(
  value: string | null,
  completedAt: number,
): number | null {
  if (value === null) {
    return null;
  }

  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) {
    return boundedRetryDelay(seconds * 1_000);
  }

  const retryAt = Date.parse(value);
  if (!Number.isFinite(retryAt)) {
    return null;
  }
  return boundedRetryDelay(Math.max(0, retryAt - completedAt));
}

function parseRetryInfo(payload: unknown): number | null {
  const error = asRecord(asRecord(payload)?.error);
  const details = error?.details;
  if (!Array.isArray(details)) {
    return null;
  }

  for (const value of details) {
    const detail = asRecord(value);
    if (
      detail?.['@type'] !== 'type.googleapis.com/google.rpc.RetryInfo'
      || typeof detail.retryDelay !== 'string'
    ) {
      continue;
    }

    const match = /^(\d+)(?:\.(\d{1,9}))?s$/.exec(detail.retryDelay);
    if (match === null) {
      continue;
    }
    const fraction = (match[2] ?? '').padEnd(9, '0');
    return boundedRetryDelay(
      Number(match[1]) * 1_000 + Number(fraction.slice(0, 3) || '0'),
    );
  }
  return null;
}

function boundedRetryDelay(value: number): number | null {
  if (!Number.isFinite(value) || value < 0) {
    return null;
  }
  return Math.min(maximumRetryAfterMs, Math.ceil(value));
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function isAbortError(error: unknown): boolean {
  return error instanceof DOMException
    ? error.name === 'AbortError'
    : asRecord(error)?.name === 'AbortError';
}
