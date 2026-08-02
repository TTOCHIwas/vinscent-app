import {
  StructuredGenerationError,
  type StructuredGenerationClient,
  type StructuredGenerationRequest,
  type StructuredGenerationResult,
} from '../application/structured-generation-client.ts';
import type {
  LearningModelUsage,
} from '../application/learning-model-port.ts';

const endpointBase = 'https://api.cloudflare.com/client/v4/accounts';
const defaultTimeoutMs = 30_000;
const defaultMaxTokens = 1_024;
const maximumInvalidOutputAttempts = 2;
const maximumRetryAfterMs = 86_400_000;
const maximumProviderErrorDetailLength = 500;
const accountIdPattern = /^[a-f0-9]{32}$/i;
const modelPattern = /^@cf\/[a-z0-9._-]+\/[a-z0-9._-]+$/i;
const qwen3ModelPattern = /^@cf\/qwen\/qwen3(?:-|$)/i;

interface CloudflareWorkersAiStructuredGenerationClientOptions {
  accountId: string;
  apiToken: string;
  model: string;
  endpoint?: string;
  timeoutMs?: number;
  maxTokens?: number;
  fetcher?: typeof fetch;
  now?: () => number;
}

export class CloudflareWorkersAiStructuredGenerationClient
  implements StructuredGenerationClient {
  readonly #apiToken: string;
  readonly #endpoint: string;
  readonly #timeoutMs: number;
  readonly #maxTokens: number;
  readonly #systemInstructionSuffix: string | null;
  readonly #fetcher: typeof fetch;
  readonly #now: () => number;

  constructor(
    options: CloudflareWorkersAiStructuredGenerationClientOptions,
  ) {
    const accountId = requireAccountId(options.accountId);
    const model = requireModel(options.model);
    this.#apiToken = requireValue(options.apiToken, 'API token');
    this.#endpoint = options.endpoint === undefined
      ? `${endpointBase}/${accountId}/ai/run/${model}`
      : requireHttpsEndpoint(options.endpoint);
    this.#timeoutMs = requirePositiveInteger(
      options.timeoutMs ?? defaultTimeoutMs,
      'timeout',
    );
    this.#maxTokens = requirePositiveInteger(
      options.maxTokens ?? defaultMaxTokens,
      'max tokens',
    );
    this.#systemInstructionSuffix = qwen3ModelPattern.test(model)
      ? '/no_think'
      : null;
    this.#fetcher = options.fetcher ?? fetch;
    this.#now = options.now ?? Date.now;
  }

  async generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<StructuredGenerationResult> {
    const prompt = request.prompt.trim();
    if (prompt.length === 0) {
      throw new TypeError('Cloudflare Workers AI prompt is required');
    }
    const systemInstruction = appendInstructionSuffix(
      optionalText(request.systemInstruction, 'system instruction'),
      this.#systemInstructionSuffix,
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
          systemInstruction,
          prompt,
          schema: request.schema,
          temperature,
          maxTokens,
        });
        return {
          ...result,
          usage: accumulatedUsage === null
            ? result.usage
            : combineUsage(accumulatedUsage, result.usage),
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
        throw copyErrorWithUsage(error, accumulatedUsage);
      }
    }

    throw new Error('Cloudflare Workers AI retry loop exhausted');
  }

  async #generateOnce(
    request: {
      systemInstruction: string | null;
      prompt: string;
      schema: Record<string, unknown>;
      temperature: number | null;
      maxTokens: number;
    },
  ): Promise<StructuredGenerationResult> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.#timeoutMs);
    const startedAt = this.#now();

    try {
      const response = await this.#fetcher(this.#endpoint, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.#apiToken}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          messages: [
            ...(request.systemInstruction === null
              ? []
              : [{
                  role: 'system',
                  content: request.systemInstruction,
                }]),
            { role: 'user', content: request.prompt },
          ],
          response_format: {
            type: 'json_schema',
            json_schema: request.schema,
          },
          stream: false,
          max_tokens: request.maxTokens,
          ...(request.temperature === null
            ? {}
            : { temperature: request.temperature }),
        }),
        signal: controller.signal,
      });

      const completedAt = this.#now();
      const latencyMs = Math.max(0, completedAt - startedAt);
      const payload = await readJsonResponse(response, latencyMs);
      if (!response.ok || asRecord(payload)?.success !== true) {
        throw providerErrorForResponse(
          response,
          payload,
          completedAt,
          latencyMs,
        );
      }

      const usage = readUsage(payload, latencyMs);
      return {
        value: readStructuredValue(payload, usage),
        usage,
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

function appendInstructionSuffix(
  instruction: string | null,
  suffix: string | null,
): string | null {
  if (suffix === null) {
    return instruction;
  }
  return instruction === null ? suffix : `${instruction}\n${suffix}`;
}

function optionalText(value: string | undefined, name: string): string | null {
  if (value === undefined) {
    return null;
  }
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`Cloudflare Workers AI ${name} is required`);
  }
  return normalized;
}

function optionalTemperature(value: number | undefined): number | null {
  if (value === undefined) {
    return null;
  }
  if (!Number.isFinite(value) || value < 0 || value > 2) {
    throw new RangeError(
      'Cloudflare Workers AI temperature must be between 0 and 2',
    );
  }
  return value;
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
): StructuredGenerationError {
  return new StructuredGenerationError({
    code: error.code,
    retryable: error.retryable,
    providerHttpStatus: error.providerHttpStatus,
    providerErrorStatus: error.providerErrorStatus,
    diagnosticDetail: error.diagnosticDetail,
    retryAfterMs: error.retryAfterMs,
    usage,
    cause: error,
  });
}

function requireAccountId(value: string): string {
  const normalized = value.trim();
  if (!accountIdPattern.test(normalized)) {
    throw new TypeError('Cloudflare account ID has an invalid format');
  }
  return normalized;
}

function requireModel(value: string): string {
  const normalized = value.trim();
  if (!modelPattern.test(normalized)) {
    throw new TypeError('Cloudflare Workers AI model has an invalid format');
  }
  return normalized;
}

function requireValue(value: string, name: string): string {
  const normalized = value.trim();
  if (normalized.length === 0) {
    throw new TypeError(`Cloudflare Workers AI ${name} is required`);
  }
  return normalized;
}

function requirePositiveInteger(value: number, name: string): number {
  if (!Number.isInteger(value) || value <= 0) {
    throw new RangeError(
      `Cloudflare Workers AI ${name} must be a positive integer`,
    );
  }
  return value;
}

function requireHttpsEndpoint(value: string): string {
  const normalized = requireValue(value, 'endpoint');
  let endpoint: URL;
  try {
    endpoint = new URL(normalized);
  } catch (error) {
    throw new TypeError('Cloudflare Workers AI endpoint is invalid', {
      cause: error,
    });
  }
  if (
    endpoint.protocol !== 'https:'
    || endpoint.username.length > 0
    || endpoint.password.length > 0
  ) {
    throw new TypeError(
      'Cloudflare Workers AI endpoint must be an HTTPS URL without credentials',
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
): unknown {
  const result = asRecord(asRecord(payload)?.result);
  if (result === null) {
    throw invalidOutputError(undefined, usage);
  }

  if ('response' in result) {
    return parseStructuredContent(result.response, usage);
  }

  const choices = result.choices;
  const firstChoice = Array.isArray(choices) ? asRecord(choices[0]) : null;
  const message = asRecord(firstChoice?.message);
  if (message !== null && 'content' in message) {
    return parseStructuredContent(message.content, usage);
  }

  throw invalidOutputError(undefined, usage);
}

function parseStructuredContent(
  content: unknown,
  usage: LearningModelUsage,
): unknown {
  if (typeof content === 'string') {
    try {
      return JSON.parse(content);
    } catch (error) {
      throw invalidOutputError(error, usage);
    }
  }
  if (typeof content === 'object' && content !== null) {
    return content;
  }
  throw invalidOutputError(undefined, usage);
}

function readUsage(
  payload: unknown,
  latencyMs: number,
): LearningModelUsage {
  const result = asRecord(asRecord(payload)?.result);
  const usage = asRecord(result?.usage);
  return {
    inputTokenCount: readFirstNonNegativeInteger(usage, [
      'prompt_tokens',
      'input_tokens',
      'promptTokens',
    ]),
    outputTokenCount: readFirstNonNegativeInteger(usage, [
      'completion_tokens',
      'output_tokens',
      'completionTokens',
    ]),
    latencyMs,
  };
}

function readFirstNonNegativeInteger(
  record: Record<string, unknown> | null,
  keys: string[],
): number | null {
  for (const key of keys) {
    const value = record?.[key];
    if (Number.isInteger(value) && Number(value) >= 0) {
      return Number(value);
    }
  }
  return null;
}

function providerErrorForResponse(
  response: Response,
  payload: unknown,
  completedAt: number,
  latencyMs: number,
): StructuredGenerationError {
  const providerCode = readProviderCode(payload);
  const diagnostics = {
    providerHttpStatus: response.status,
    providerErrorStatus: providerCode === null
      ? null
      : `CF_${providerCode}`,
    diagnosticDetail: readProviderErrorDetail(payload),
    retryAfterMs: readRetryAfterMs(response, completedAt),
    usage: emptyUsage(latencyMs),
  };

  if (providerCode === 3036) {
    return new StructuredGenerationError({
      code: 'rate_limited',
      retryable: true,
      ...diagnostics,
    });
  }
  if (providerCode === 3040) {
    return new StructuredGenerationError({
      code: 'provider_unavailable',
      retryable: true,
      ...diagnostics,
    });
  }
  if (providerCode === 3007 || providerCode === 3008) {
    return new StructuredGenerationError({
      code: 'timeout',
      retryable: true,
      ...diagnostics,
    });
  }
  if (providerCode === 5007 || providerCode === 3042) {
    return new StructuredGenerationError({
      code: 'model_not_found',
      retryable: false,
      ...diagnostics,
    });
  }
  if (
    providerCode === 5018
    || providerCode === 5016
    || providerCode === 3023
    || providerCode === 3041
    || providerCode === 5035
  ) {
    return new StructuredGenerationError({
      code: 'auth_failed',
      retryable: false,
      ...diagnostics,
    });
  }
  if (
    providerCode === 5004
    || providerCode === 3039
    || providerCode === 3003
    || providerCode === 3006
    || providerCode === 5019
    || providerCode === 5005
  ) {
    return new StructuredGenerationError({
      code: 'invalid_request',
      retryable: false,
      ...diagnostics,
    });
  }

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
    || response.status === 405
    || response.status === 413
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

function readProviderCode(payload: unknown): number | null {
  const errors = asRecord(payload)?.errors;
  if (!Array.isArray(errors)) {
    return null;
  }
  for (const value of errors) {
    const code = asRecord(value)?.code;
    if (Number.isInteger(code) && Number(code) >= 0) {
      return Number(code);
    }
  }
  return null;
}

function readProviderErrorDetail(payload: unknown): string | null {
  const errors = asRecord(payload)?.errors;
  if (!Array.isArray(errors)) {
    return null;
  }
  for (const value of errors) {
    const message = asRecord(value)?.message;
    if (typeof message === 'string') {
      return sanitizeDiagnosticDetail(message);
    }
  }
  return null;
}

function sanitizeDiagnosticDetail(value: string): string | null {
  const normalized = value
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

function invalidOutputError(
  cause: unknown,
  usage: LearningModelUsage,
): StructuredGenerationError {
  return new StructuredGenerationError({
    code: 'invalid_output',
    retryable: false,
    usage,
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
