import {
  StructuredGenerationError,
  type StructuredGenerationClient,
  type StructuredGenerationRequest,
  type StructuredGenerationResult,
} from '../application/structured-generation-client.ts';
import type {
  LearningModelUsage,
} from '../application/learning-model-port.ts';

const defaultEndpointBase =
  'https://generativelanguage.googleapis.com/v1beta/models';
const defaultModel = 'gemini-3.1-flash-lite';
const defaultTimeoutMs = 30_000;
const maximumRetryAfterMs = 86_400_000;
const maximumProviderErrorDetailLength = 500;
const defaultSafetySettings = [
  {
    category: 'HARM_CATEGORY_HARASSMENT',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
  {
    category: 'HARM_CATEGORY_HATE_SPEECH',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
  {
    category: 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
  {
    category: 'HARM_CATEGORY_DANGEROUS_CONTENT',
    threshold: 'BLOCK_MEDIUM_AND_ABOVE',
  },
] as const;
const safetyFinishReasons = new Set([
  'SAFETY',
  'BLOCKLIST',
  'PROHIBITED_CONTENT',
  'SPII',
  'IMAGE_SAFETY',
  'IMAGE_PROHIBITED_CONTENT',
  'ESCALATION',
]);

interface GeminiStructuredGenerationClientOptions {
  apiKey: string;
  model?: string;
  endpoint?: string;
  timeoutMs?: number;
  fetcher?: typeof fetch;
  now?: () => number;
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
    const prompt = request.prompt.trim();
    if (prompt.length === 0) {
      throw new TypeError('Gemini prompt is required');
    }
    const systemInstruction = optionalText(
      request.systemInstruction,
      'system instruction',
    );
    const temperature = optionalTemperature(request.temperature);
    const maxOutputTokens = request.maxOutputTokens === undefined
      ? null
      : requirePositiveInteger(
          request.maxOutputTokens,
          'max output tokens',
        );

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
          ...(systemInstruction === null
            ? {}
            : {
                systemInstruction: {
                  parts: [{ text: systemInstruction }],
                },
              }),
          contents: [
            {
              role: 'user',
              parts: [{ text: prompt }],
            },
          ],
          safetySettings: defaultSafetySettings,
          generationConfig: {
            responseMimeType: 'application/json',
            responseJsonSchema: request.schema,
            ...(temperature === null ? {} : { temperature }),
            ...(maxOutputTokens === null ? {} : { maxOutputTokens }),
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

      const rawUsage = readUsage(payload);
      const usage = {
        inputTokenCount: rawUsage.inputTokenCount,
        outputTokenCount: rawUsage.outputTokenCount,
        latencyMs,
      };
      throwForSafetyBlock(payload, usage);
      const outputText = readOutputText(payload, latencyMs);
      let value: unknown;
      try {
        value = JSON.parse(outputText);
      } catch (error) {
        throw invalidOutputError(error, latencyMs);
      }

      return {
        value,
        usage,
      };
    } catch (error) {
      if (error instanceof StructuredGenerationError) {
        throw error;
      }

      if (isAbortError(error)) {
        throw new StructuredGenerationError({
          code: 'timeout',
          retryable: true,
          usage: emptyUsage(Math.max(0, this.#now() - startedAt)),
          cause: error,
        });
      }

      throw new StructuredGenerationError({
        code: 'network_error',
        retryable: true,
        usage: emptyUsage(Math.max(0, this.#now() - startedAt)),
        cause: error,
      });
    } finally {
      clearTimeout(timeout);
    }
  }
}

function optionalText(value: string | undefined, name: string): string | null {
  if (value === undefined) {
    return null;
  }
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`Gemini ${name} is required`);
  }
  return normalized;
}

function optionalTemperature(value: number | undefined): number | null {
  if (value === undefined) {
    return null;
  }
  if (!Number.isFinite(value) || value < 0 || value > 2) {
    throw new RangeError('Gemini temperature must be between 0 and 2');
  }
  return value;
}

function requirePositiveInteger(value: number, name: string): number {
  if (!Number.isInteger(value) || value <= 0) {
    throw new RangeError(`Gemini ${name} must be a positive integer`);
  }
  return value;
}

function invalidOutputError(
  cause: unknown,
  latencyMs: number,
): StructuredGenerationError {
  return new StructuredGenerationError({
    code: 'invalid_output',
    retryable: false,
    usage: emptyUsage(latencyMs),
    cause,
  });
}

function emptyUsage(latencyMs: number): LearningModelUsage {
  return {
    inputTokenCount: null,
    outputTokenCount: null,
    latencyMs,
  };
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
      throw invalidOutputError(error, latencyMs);
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
    throw invalidOutputError(undefined, latencyMs);
  }
  return text;
}

function throwForSafetyBlock(
  payload: unknown,
  usage: LearningModelUsage,
): void {
  const record = asRecord(payload);
  const promptFeedback = asRecord(record?.promptFeedback);
  const blockReason = promptFeedback?.blockReason;
  if (
    typeof blockReason === 'string'
    && blockReason.length > 0
    && blockReason !== 'BLOCK_REASON_UNSPECIFIED'
  ) {
    throw new StructuredGenerationError({
      code: 'content_blocked',
      retryable: false,
      diagnosticDetail: 'prompt_blocked',
      usage,
    });
  }

  const candidates = Array.isArray(record?.candidates)
    ? record.candidates
    : [];
  if (
    candidates.some((candidate) => {
      const finishReason = asRecord(candidate)?.finishReason;
      return typeof finishReason === 'string'
        && safetyFinishReasons.has(finishReason);
    })
  ) {
    throw new StructuredGenerationError({
      code: 'content_blocked',
      retryable: false,
      diagnosticDetail: 'candidate_blocked',
      usage,
    });
  }
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
): StructuredGenerationError {
  const status = response.status;
  const diagnostics = {
    providerHttpStatus: status,
    providerErrorStatus: readProviderStatus(payload),
    diagnosticDetail: readProviderErrorDetail(payload),
    retryAfterMs: readRetryAfterMs(response, payload, completedAt),
    usage: emptyUsage(latencyMs),
  };

  if (status === 429) {
    return new StructuredGenerationError({
      code: 'rate_limited',
      retryable: true,
      ...diagnostics,
    });
  }
  if (status === 408 || status === 409 || status >= 500) {
    return new StructuredGenerationError({
      code: 'provider_unavailable',
      retryable: true,
      ...diagnostics,
    });
  }
  if (status === 400) {
    return new StructuredGenerationError({
      code: 'invalid_request',
      retryable: false,
      ...diagnostics,
    });
  }
  if (status === 401 || status === 403) {
    return new StructuredGenerationError({
      code: 'auth_failed',
      retryable: false,
      ...diagnostics,
    });
  }
  if (status === 404) {
    return new StructuredGenerationError({
      code: 'model_not_found',
      retryable: false,
      ...diagnostics,
    });
  }
  return new StructuredGenerationError({
    code: 'request_failed',
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
