import {
  StructuredGenerationError,
  type StructuredGenerationClient,
  type StructuredGenerationErrorCode,
  type StructuredGenerationRequest,
  type StructuredGenerationResult,
} from '../application/structured-generation-client.ts';
import type {
  LearningModelDiagnostics,
  LearningModelUsage,
} from '../application/learning-model-port.ts';

const defaultEndpoint = 'https://api.openai.com/v1/responses';
const defaultTimeoutMs = 30_000;
const defaultMaxTokens = 1_024;
const maximumInvalidOutputAttempts = 2;
const maximumAdaptiveMaxTokens = 32_768;
const maximumRetryAfterMs = 86_400_000;
const maximumProviderErrorDetailLength = 500;
const modelPattern = /^[a-z0-9][a-z0-9._:-]{0,127}$/i;

export type OpenAiReasoningEffort =
  | 'none'
  | 'minimal'
  | 'low'
  | 'medium'
  | 'high'
  | 'xhigh'
  | 'max';

interface OpenAiResponsesStructuredGenerationClientOptions {
  apiKey: string;
  model: string;
  reasoningEffort?: OpenAiReasoningEffort;
  endpoint?: string;
  timeoutMs?: number;
  maxTokens?: number;
  fetcher?: typeof fetch;
  now?: () => number;
}

export class OpenAiResponsesStructuredGenerationClient
  implements StructuredGenerationClient {
  readonly #apiKey: string;
  readonly #model: string;
  readonly #reasoningEffort: OpenAiReasoningEffort;
  readonly #endpoint: string;
  readonly #timeoutMs: number;
  readonly #maxTokens: number;
  readonly #fetcher: typeof fetch;
  readonly #now: () => number;

  constructor(options: OpenAiResponsesStructuredGenerationClientOptions) {
    this.#apiKey = requireValue(options.apiKey, 'API key');
    this.#model = requireModel(options.model);
    this.#reasoningEffort = requireReasoningEffort(
      options.reasoningEffort ?? defaultReasoningEffort(this.#model),
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
      throw new TypeError('OpenAI prompt is required');
    }
    const systemInstruction = optionalText(
      request.systemInstruction,
      'system instruction',
    );
    const temperature = optionalTemperature(request.temperature);
    const requestedMaxTokens = request.maxOutputTokens === undefined
      ? this.#maxTokens
      : requirePositiveInteger(request.maxOutputTokens, 'max output tokens');
    let providerMaxTokens = resolveProviderMaxOutputTokens(
      requestedMaxTokens,
      this.#reasoningEffort,
    );

    let accumulatedUsage: LearningModelUsage | null = null;
    for (
      let attempt = 0;
      attempt < maximumInvalidOutputAttempts;
      attempt += 1
    ) {
      try {
        const result = await this.#generateOnce({
          systemInstruction,
          prompt,
          schema: request.schema,
          temperature,
          maxTokens: providerMaxTokens,
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
          if (error.diagnostics?.completionReason === 'max_output_tokens') {
            providerMaxTokens = Math.min(
              maximumAdaptiveMaxTokens,
              providerMaxTokens * 2,
            );
          }
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

    throw new Error('OpenAI retry loop exhausted');
  }

  async #generateOnce(request: {
    systemInstruction: string | null;
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
          input: [
            ...(request.systemInstruction === null
              ? []
              : [{
                  role: 'system',
                  content: request.systemInstruction,
                }]),
            { role: 'user', content: request.prompt },
          ],
          text: {
            format: {
              type: 'json_schema',
              name: 'vinscent_structured_response',
              strict: true,
              schema: request.schema,
            },
          },
          reasoning: { effort: this.#reasoningEffort },
          store: false,
          max_output_tokens: request.maxTokens,
          ...(this.#reasoningEffort === 'none'
              && request.temperature !== null
            ? { temperature: request.temperature }
            : {}),
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
      throwForIncompleteResponse(payload, usage, diagnostics);
      throwForFailedResponse(payload, usage, diagnostics);
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

function optionalText(value: string | undefined, name: string): string | null {
  if (value === undefined) {
    return null;
  }
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`OpenAI ${name} is required`);
  }
  return normalized;
}

function optionalTemperature(value: number | undefined): number | null {
  if (value === undefined) {
    return null;
  }
  if (!Number.isFinite(value) || value < 0 || value > 2) {
    throw new RangeError('OpenAI temperature must be between 0 and 2');
  }
  return value;
}

function requireReasoningEffort(value: string): OpenAiReasoningEffort {
  if (
    value === 'none'
    || value === 'minimal'
    || value === 'low'
    || value === 'medium'
    || value === 'high'
    || value === 'xhigh'
    || value === 'max'
  ) {
    return value;
  }
  throw new TypeError(
    'OpenAI reasoning effort must be none, minimal, low, medium, high, xhigh, or max',
  );
}

function defaultReasoningEffort(modelName: string): OpenAiReasoningEffort {
  const normalized = modelName.toLowerCase();
  const isGpt5Nano = normalized === 'gpt-5-nano'
    || normalized.startsWith('gpt-5-nano-');
  return isGpt5Nano ? 'minimal' : 'none';
}

function resolveProviderMaxOutputTokens(
  requestedMaxTokens: number,
  reasoningEffort: OpenAiReasoningEffort,
): number {
  const minimumByEffort: Record<OpenAiReasoningEffort, number> = {
    none: 0,
    minimal: 0,
    low: 2_048,
    medium: 4_096,
    high: 8_192,
    xhigh: 16_384,
    max: 32_768,
  };
  return Math.max(requestedMaxTokens, minimumByEffort[reasoningEffort]);
}

function requireModel(value: string): string {
  const normalized = value.trim();
  if (!modelPattern.test(normalized)) {
    throw new TypeError('OpenAI model has an invalid format');
  }
  return normalized;
}

function requireValue(value: string, name: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`OpenAI ${name} is required`);
  }
  return normalized;
}

function requirePositiveInteger(value: number, name: string): number {
  if (!Number.isInteger(value) || value <= 0) {
    throw new RangeError(`OpenAI ${name} must be a positive integer`);
  }
  return value;
}

function requireHttpsEndpoint(value: string): string {
  const normalized = requireValue(value, 'endpoint');
  let endpoint: URL;
  try {
    endpoint = new URL(normalized);
  } catch (error) {
    throw new TypeError('OpenAI endpoint is invalid', { cause: error });
  }
  if (
    endpoint.protocol !== 'https:'
    || endpoint.username.length > 0
    || endpoint.password.length > 0
  ) {
    throw new TypeError(
      'OpenAI endpoint must be an HTTPS URL without credentials',
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
  const outputText = readOutputParts(payload)
    .filter((part) => part.type === 'output_text')
    .map((part) => part.text)
    .filter((value): value is string => typeof value === 'string')
    .join('')
    .trim();
  if (outputText.length === 0) {
    throw invalidOutputError(undefined, usage, diagnostics);
  }
  try {
    return JSON.parse(outputText);
  } catch (error) {
    throw invalidOutputError(error, usage, diagnostics);
  }
}

function throwForContentBlock(
  payload: unknown,
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics,
): void {
  const refusal = readOutputParts(payload).some((part) => (
    part.type === 'refusal'
    && typeof part.refusal === 'string'
    && part.refusal.trim().length > 0
  ));
  const incompleteReason = readIncompleteReason(payload);
  if (
    refusal
    || incompleteReason === 'content_filter'
    || incompleteReason === 'safety'
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

function throwForIncompleteResponse(
  payload: unknown,
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics,
): void {
  if (asRecord(payload)?.status === 'incomplete') {
    throw invalidOutputError(undefined, usage, diagnostics);
  }
}

function throwForFailedResponse(
  payload: unknown,
  usage: LearningModelUsage,
  diagnostics: LearningModelDiagnostics,
): void {
  const status = asRecord(payload)?.status;
  if (status !== 'failed' && status !== 'cancelled') {
    return;
  }
  const rawStatus = readRawProviderStatus(payload);
  const classification = classifyFailedResponse(rawStatus);
  throw new StructuredGenerationError({
    code: classification.code,
    retryable: classification.retryable,
    providerHttpStatus: 200,
    providerErrorStatus: prefixedProviderStatus(rawStatus),
    diagnosticDetail: readProviderErrorDetail(payload),
    usage,
    diagnostics,
  });
}

function classifyFailedResponse(rawStatus: string | null): {
  code: StructuredGenerationErrorCode;
  retryable: boolean;
} {
  if (rawStatus === 'content_policy_violation' || rawStatus === 'content_filter') {
    return { code: 'content_blocked', retryable: false };
  }
  if (rawStatus === 'rate_limit_exceeded' || rawStatus === 'rate_limit_error') {
    return { code: 'rate_limited', retryable: true };
  }
  if (
    rawStatus === 'server_error'
    || rawStatus === 'internal_error'
    || rawStatus === 'service_unavailable'
    || rawStatus === 'temporarily_unavailable'
  ) {
    return { code: 'provider_unavailable', retryable: true };
  }
  if (rawStatus === 'authentication_error' || rawStatus === 'invalid_api_key') {
    return { code: 'auth_failed', retryable: false };
  }
  if (rawStatus === 'model_not_found') {
    return { code: 'model_not_found', retryable: false };
  }
  if (rawStatus === 'invalid_request_error' || rawStatus === 'invalid_argument') {
    return { code: 'invalid_request', retryable: false };
  }
  return { code: 'request_failed', retryable: false };
}

function readOutputParts(payload: unknown): Array<Record<string, unknown>> {
  const output = asRecord(payload)?.output;
  if (!Array.isArray(output)) {
    return [];
  }
  const parts: Array<Record<string, unknown>> = [];
  for (const item of output) {
    const content = asRecord(item)?.content;
    if (!Array.isArray(content)) {
      continue;
    }
    for (const part of content) {
      const record = asRecord(part);
      if (record !== null) {
        parts.push(record);
      }
    }
  }
  return parts;
}

function readDiagnostics(payload: unknown): LearningModelDiagnostics {
  const status = normalizeCompletionReason(asRecord(payload)?.status);
  const incompleteReason = readIncompleteReason(payload);
  return diagnosticsForAttempt(1, incompleteReason ?? status);
}

function readIncompleteReason(payload: unknown): string | null {
  return normalizeCompletionReason(
    asRecord(asRecord(payload)?.incomplete_details)?.reason,
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
    inputTokenCount: readNonNegativeInteger(usage?.input_tokens),
    outputTokenCount: readNonNegativeInteger(usage?.output_tokens),
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
  const rawStatus = readRawProviderStatus(payload);
  const params = {
    providerHttpStatus: response.status,
    providerErrorStatus: prefixedProviderStatus(rawStatus),
    diagnosticDetail: readProviderErrorDetail(payload),
    retryAfterMs: readRetryAfterMs(response, completedAt),
    usage: emptyUsage(latencyMs),
  };
  if (rawStatus === 'content_policy_violation' || rawStatus === 'content_filter') {
    return new StructuredGenerationError({
      code: 'content_blocked',
      retryable: false,
      ...params,
    });
  }
  if (response.status === 429) {
    return new StructuredGenerationError({
      code: 'rate_limited',
      retryable: true,
      ...params,
    });
  }
  if (response.status === 401 || response.status === 403) {
    return new StructuredGenerationError({
      code: 'auth_failed',
      retryable: false,
      ...params,
    });
  }
  if (response.status === 404) {
    return new StructuredGenerationError({
      code: 'model_not_found',
      retryable: false,
      ...params,
    });
  }
  if (response.status === 408) {
    return new StructuredGenerationError({
      code: 'timeout',
      retryable: true,
      ...params,
    });
  }
  if (
    response.status === 409
    || response.status === 425
    || response.status >= 500
  ) {
    return new StructuredGenerationError({
      code: 'provider_unavailable',
      retryable: true,
      ...params,
    });
  }
  if (response.status === 400 || response.status === 422) {
    return new StructuredGenerationError({
      code: 'invalid_request',
      retryable: false,
      ...params,
    });
  }
  return new StructuredGenerationError({
    code: 'request_failed',
    retryable: false,
    ...params,
  });
}

function readRawProviderStatus(payload: unknown): string | null {
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
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 90);
  return normalized.length === 0 ? null : normalized;
}

function prefixedProviderStatus(value: string | null): string | null {
  return value === null ? null : `OPENAI_${value.toUpperCase()}`;
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
    .replace(/\bsk-[0-9A-Za-z_-]{12,}\b/g, '[REDACTED]')
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

function sumKnownCounts(first: number | null, second: number | null): number | null {
  return first === null || second === null ? null : first + second;
}

function emptyUsage(latencyMs: number): LearningModelUsage {
  return {
    inputTokenCount: null,
    outputTokenCount: null,
    latencyMs,
  };
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

function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError';
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}
