import {
  StructuredGenerationError,
  type StructuredGenerationClient,
  type StructuredGenerationRequest,
  type StructuredGenerationResult,
} from '../application/structured-generation-client.ts';
import type {
  LearningModelDiagnostics,
  LearningModelUsage,
} from '../application/learning-model-port.ts';

const defaultEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
const defaultTimeoutMs = 30_000;
const defaultMaxTokens = 1_024;
const maximumInvalidOutputAttempts = 3;
const maximumRetryAfterMs = 86_400_000;
const maximumProviderErrorDetailLength = 500;
const modelPattern = /^[a-z0-9._-]+\/[a-z0-9._-]+$/i;

export type GroqReasoningEffort = 'low' | 'medium' | 'high';

interface GroqStructuredGenerationClientOptions {
  apiKey: string;
  model: string;
  reasoningEffort?: GroqReasoningEffort;
  endpoint?: string;
  timeoutMs?: number;
  maxTokens?: number;
  fetcher?: typeof fetch;
  now?: () => number;
}

export class GroqStructuredGenerationClient
  implements StructuredGenerationClient {
  readonly #apiKey: string;
  readonly #model: string;
  readonly #reasoningEffort: GroqReasoningEffort;
  readonly #endpoint: string;
  readonly #timeoutMs: number;
  readonly #maxTokens: number;
  readonly #fetcher: typeof fetch;
  readonly #now: () => number;

  constructor(options: GroqStructuredGenerationClientOptions) {
    this.#apiKey = requireValue(options.apiKey, 'API key');
    this.#model = requireModel(options.model);
    this.#reasoningEffort = requireReasoningEffort(
      options.reasoningEffort ?? 'low',
    );
    this.#endpoint = options.endpoint === undefined
      ? defaultEndpoint
      : requireHttpsEndpoint(options.endpoint);
    this.#timeoutMs = requirePositiveInteger(
      options.timeoutMs ?? defaultTimeoutMs,
      'timeout',
    );
    this.#maxTokens = requirePositiveInteger(
      options.maxTokens ?? defaultMaxTokens,
      'max tokens',
    );
    this.#fetcher = options.fetcher ?? fetch;
    this.#now = options.now ?? Date.now;
  }

  async generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<StructuredGenerationResult> {
    const prompt = request.prompt.trim();
    if (prompt.length === 0) {
      throw new TypeError('Groq prompt is required');
    }
    const systemInstruction = optionalText(
      request.systemInstruction,
      'system instruction',
    );
    const temperature = optionalTemperature(request.temperature);
    const maxTokens = request.maxOutputTokens === undefined
      ? this.#maxTokens
      : requirePositiveInteger(request.maxOutputTokens, 'max output tokens');

    let accumulatedUsage: LearningModelUsage | null = null;
    for (
      let attempt = 0;
      attempt < maximumInvalidOutputAttempts;
      attempt += 1
    ) {
      try {
        const result = await this.#generateOnce({
          prompt: mergePrompt(systemInstruction, prompt),
          schema: request.schema,
          temperature,
          maxTokens,
        });
        return {
          ...result,
          usage: accumulatedUsage === null
            ? result.usage
            : combineUsage(accumulatedUsage, result.usage),
          diagnostics: diagnosticsForAttempt(
            attempt + 1,
            result.diagnostics?.completionReason ?? null,
          ),
        };
      } catch (error) {
        if (!(error instanceof StructuredGenerationError)) {
          throw error;
        }

        accumulatedUsage = accumulatedUsage === null
          ? error.usage
          : combineUsage(accumulatedUsage, error.usage);
        if (
          error.code === 'invalid_output'
          && attempt + 1 < maximumInvalidOutputAttempts
        ) {
          continue;
        }
        throw copyErrorWithUsage(
          error,
          accumulatedUsage,
          diagnosticsForAttempt(
            attempt + 1,
            error.diagnostics?.completionReason ?? null,
          ),
        );
      }
    }

    throw new Error('Groq retry loop exhausted');
  }

  async #generateOnce(request: {
    prompt: string;
    schema: Record<string, unknown>;
    temperature: number | null;
    maxTokens: number;
  }): Promise<StructuredGenerationResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.#timeoutMs);
    const startedAt = this.#now();

    try {
      const response = await this.#fetcher(this.#endpoint, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.#apiKey}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          model: this.#model,
          messages: [{ role: 'user', content: request.prompt }],
          response_format: {
            type: 'json_schema',
            json_schema: {
              name: 'vinscent_structured_response',
              strict: true,
              schema: request.schema,
            },
          },
          reasoning_effort: this.#reasoningEffort,
          include_reasoning: false,
          stream: false,
          max_completion_tokens: request.maxTokens,
          ...(request.temperature === null
            ? {}
            : { temperature: request.temperature }),
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

      const usage = readUsage(payload, latencyMs);
      const diagnostics = readDiagnostics(payload);
      throwForContentBlock(payload, usage, diagnostics);
      throwForIncompleteCompletion(usage, diagnostics);
      return {
        value: readStructuredValue(payload, usage, diagnostics),
        usage,
        diagnostics,
      };
    } catch (error) {
      if (error instanceof StructuredGenerationError) {
        throw error;
      }

      const latencyMs = Math.max(0, this.#now() - startedAt);
      if (isAbortError(error)) {
        throw new StructuredGenerationError({
          code: 'timeout',
          retryable: true,
          usage: emptyUsage(latencyMs),
          cause: error,
        });
      }

      throw new StructuredGenerationError({
        code: 'network_error',
        retryable: true,
        usage: emptyUsage(latencyMs),
        cause: error,
      });
    } finally {
      clearTimeout(timeout);
    }
  }
}

function mergePrompt(
  systemInstruction: string | null,
  prompt: string,
): string {
  return systemInstruction === null
    ? prompt
    : `${systemInstruction}\n\n${prompt}`;
}

function optionalText(value: string | undefined, name: string): string | null {
  if (value === undefined) {
    return null;
  }
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`Groq ${name} is required`);
  }
  return normalized;
}

function optionalTemperature(value: number | undefined): number | null {
  if (value === undefined) {
    return null;
  }
  if (!Number.isFinite(value) || value < 0 || value > 2) {
    throw new RangeError('Groq temperature must be between 0 and 2');
  }
  return value;
}

function requireReasoningEffort(value: string): GroqReasoningEffort {
  if (value === 'low' || value === 'medium' || value === 'high') {
    return value;
  }
  throw new TypeError('Groq reasoning effort must be low, medium, or high');
}

function requireModel(value: string): string {
  const normalized = value.trim();
  if (!modelPattern.test(normalized)) {
    throw new TypeError('Groq model has an invalid format');
  }
  return normalized;
}

function requireValue(value: string, name: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`Groq ${name} is required`);
  }
  return normalized;
}

function requirePositiveInteger(value: number, name: string): number {
  if (!Number.isInteger(value) || value <= 0) {
    throw new RangeError(`Groq ${name} must be a positive integer`);
  }
  return value;
}

function requireHttpsEndpoint(value: string): string {
  const normalized = requireValue(value, 'endpoint');
  let endpoint: URL;
  try {
    endpoint = new URL(normalized);
  } catch (error) {
    throw new TypeError('Groq endpoint is invalid', { cause: error });
  }
  if (
    endpoint.protocol !== 'https:'
    || endpoint.username.length > 0
    || endpoint.password.length > 0
  ) {
    throw new TypeError(
      'Groq endpoint must be an HTTPS URL without credentials',
    );
  }
  return endpoint.toString();
}

async function readJsonResponse(
  response: Response,
  latencyMs: number,
): Promise<unknown> {
  try {
    return await response.json();
  } catch (error) {
    if (response.ok) {
      throw invalidOutputError(error, emptyUsage(latencyMs));
    }
    return null;
  }
}

function readStructuredValue(
  payload: unknown,
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics,
): unknown {
  const choices = asRecord(payload)?.choices;
  const firstChoice = Array.isArray(choices) ? asRecord(choices[0]) : null;
  const content = asRecord(firstChoice?.message)?.content;
  if (typeof content !== 'string' || content.trim().length === 0) {
    throw invalidOutputError(undefined, usage, diagnostics);
  }
  try {
    return JSON.parse(content);
  } catch (error) {
    throw invalidOutputError(error, usage, diagnostics);
  }
}

function throwForContentBlock(
  payload: unknown,
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics,
): void {
  const choices = asRecord(payload)?.choices;
  const firstChoice = Array.isArray(choices) ? asRecord(choices[0]) : null;
  const message = asRecord(firstChoice?.message);
  const refusal = message?.refusal;
  const finishReason = firstChoice?.finish_reason;
  if (
    (typeof refusal === 'string' && refusal.trim().length > 0)
    || finishReason === 'content_filter'
  ) {
    throw new StructuredGenerationError({
      code: 'content_blocked',
      retryable: false,
      diagnosticDetail: 'provider_refusal',
      usage,
      diagnostics,
    });
  }
}

function throwForIncompleteCompletion(
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics,
): void {
  if (diagnostics.completionReason === 'length') {
    throw invalidOutputError(undefined, usage, diagnostics);
  }
}

function readDiagnostics(payload: unknown): LearningModelDiagnostics {
  const choices = asRecord(payload)?.choices;
  const firstChoice = Array.isArray(choices) ? asRecord(choices[0]) : null;
  return diagnosticsForAttempt(
    1,
    normalizeCompletionReason(firstChoice?.finish_reason),
  );
}

function normalizeCompletionReason(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const normalized = value.trim().toLowerCase();
  return /^[a-z0-9_.-]{1,64}$/u.test(normalized) ? normalized : null;
}

function diagnosticsForAttempt(
  providerAttemptCount: number,
  completionReason: string | null,
): LearningModelDiagnostics {
  return { providerAttemptCount, completionReason };
}

function readUsage(
  payload: unknown,
  latencyMs: number,
): LearningModelUsage {
  const usage = asRecord(asRecord(payload)?.usage);
  return {
    inputTokenCount: readNonNegativeInteger(usage?.prompt_tokens),
    outputTokenCount: readNonNegativeInteger(usage?.completion_tokens),
    latencyMs,
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
  const diagnostics = {
    providerHttpStatus: response.status,
    providerErrorStatus: readProviderStatus(payload),
    diagnosticDetail: readProviderErrorDetail(payload),
    retryAfterMs: readRetryAfterMs(response, completedAt),
    usage: emptyUsage(latencyMs),
  };

  if (response.status === 429) {
    return new StructuredGenerationError({
      code: 'rate_limited',
      retryable: true,
      ...diagnostics,
    });
  }
  if (response.status === 408) {
    return new StructuredGenerationError({
      code: 'timeout',
      retryable: true,
      ...diagnostics,
    });
  }
  if (response.status === 409 || response.status >= 500) {
    return new StructuredGenerationError({
      code: 'provider_unavailable',
      retryable: true,
      ...diagnostics,
    });
  }
  if (response.status === 401 || response.status === 403) {
    return new StructuredGenerationError({
      code: 'auth_failed',
      retryable: false,
      ...diagnostics,
    });
  }
  if (response.status === 404) {
    return new StructuredGenerationError({
      code: 'model_not_found',
      retryable: false,
      ...diagnostics,
    });
  }
  if (
    response.status === 400
    && diagnostics.providerErrorStatus === 'GROQ_JSON_VALIDATE_FAILED'
  ) {
    return new StructuredGenerationError({
      code: 'invalid_output',
      retryable: false,
      ...diagnostics,
    });
  }
  if (
    response.status === 400
    || response.status === 405
    || response.status === 413
    || response.status === 422
  ) {
    return new StructuredGenerationError({
      code: 'invalid_request',
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
  const raw = typeof error?.code === 'string'
    ? error.code
    : typeof error?.type === 'string'
    ? error.type
    : null;
  if (raw === null) {
    return null;
  }
  const normalized = raw
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 90);
  return normalized.length === 0 ? null : `GROQ_${normalized}`;
}

function readProviderErrorDetail(payload: unknown): string | null {
  const error = asRecord(asRecord(payload)?.error);
  if (typeof error?.message !== 'string') {
    return null;
  }
  return sanitizeDiagnosticDetail(error.message);
}

function sanitizeDiagnosticDetail(value: string): string | null {
  const normalized = value
    .replace(/\bgsk_[0-9A-Za-z_-]{12,}\b/g, '[REDACTED]')
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
  completedAt: number,
): number | null {
  const value = response.headers.get('retry-after');
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

function boundedRetryDelay(value: number): number | null {
  if (!Number.isFinite(value) || value < 0) {
    return null;
  }
  return Math.min(maximumRetryAfterMs, Math.ceil(value));
}

function combineUsage(
  first: LearningModelUsage,
  second: LearningModelUsage,
): LearningModelUsage {
  return {
    inputTokenCount: sumKnownCounts(
      first.inputTokenCount,
      second.inputTokenCount,
    ),
    outputTokenCount: sumKnownCounts(
      first.outputTokenCount,
      second.outputTokenCount,
    ),
    latencyMs: first.latencyMs + second.latencyMs,
  };
}

function sumKnownCounts(
  first: number | null,
  second: number | null,
): number | null {
  return first === null || second === null ? null : first + second;
}

function copyErrorWithUsage(
  error: StructuredGenerationError,
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics,
): StructuredGenerationError {
  return new StructuredGenerationError({
    code: error.code,
    retryable: error.retryable,
    providerHttpStatus: error.providerHttpStatus,
    providerErrorStatus: error.providerErrorStatus,
    diagnosticDetail: error.diagnosticDetail,
    retryAfterMs: error.retryAfterMs,
    usage,
    diagnostics,
    cause: error,
  });
}

function invalidOutputError(
  cause: unknown,
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics | null = null,
): StructuredGenerationError {
  return new StructuredGenerationError({
    code: 'invalid_output',
    retryable: false,
    usage,
    diagnostics,
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
