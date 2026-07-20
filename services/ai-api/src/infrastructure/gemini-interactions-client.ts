import type {
  LearningModelUsage,
} from '../application/learning-model-port.ts';

const defaultEndpoint =
  'https://generativelanguage.googleapis.com/v1beta/interactions';
const defaultModel = 'gemini-3.5-flash';
const defaultTimeoutMs = 30_000;

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

interface GeminiInteractionsClientOptions {
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

  constructor(params: {
    code: string;
    retryable: boolean;
    status?: number | null;
    cause?: unknown;
  }) {
    super(params.code, { cause: params.cause });
    this.name = 'GeminiProviderError';
    this.code = params.code;
    this.retryable = params.retryable;
    this.status = params.status ?? null;
  }
}

export class GeminiOutputError extends Error {
  readonly code = 'gemini_invalid_output';
  readonly retryable = false;

  constructor(cause?: unknown) {
    super('gemini_invalid_output', { cause });
    this.name = 'GeminiOutputError';
  }
}

export class GeminiInteractionsClient implements StructuredGenerationClient {
  readonly #apiKey: string;
  readonly #model: string;
  readonly #endpoint: string;
  readonly #timeoutMs: number;
  readonly #fetcher: typeof fetch;
  readonly #now: () => number;

  constructor(options: GeminiInteractionsClientOptions) {
    if (options.apiKey.trim().length === 0) {
      throw new TypeError('Gemini API key is required');
    }

    this.#apiKey = options.apiKey;
    this.#model = requireConfigValue(options.model ?? defaultModel, 'model');
    this.#endpoint = requireConfigValue(
      options.endpoint ?? defaultEndpoint,
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
          model: this.#model,
          input: request.prompt,
          generation_config: {
            temperature: 0.2,
          },
          response_format: {
            type: 'text',
            mime_type: 'application/json',
            schema: request.schema,
          },
        }),
        signal: controller.signal,
      });

      const payload = await readJsonResponse(response);
      if (!response.ok) {
        throw providerErrorForStatus(response.status);
      }

      const outputText = readOutputText(payload);
      let value: unknown;
      try {
        value = JSON.parse(outputText);
      } catch (error) {
        throw new GeminiOutputError(error);
      }

      const usage = readUsage(payload);
      return {
        value,
        usage: {
          inputTokenCount: usage.inputTokenCount,
          outputTokenCount: usage.outputTokenCount,
          latencyMs: Math.max(0, this.#now() - startedAt),
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
          cause: error,
        });
      }

      throw new GeminiProviderError({
        code: 'gemini_network_error',
        retryable: true,
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

async function readJsonResponse(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch (error) {
    if (response.ok) {
      throw new GeminiOutputError(error);
    }
    return null;
  }
}

function readOutputText(payload: unknown): string {
  const record = asRecord(payload);
  if (typeof record?.output_text === 'string' && record.output_text.length > 0) {
    return record.output_text;
  }

  const interaction = asRecord(record?.interaction);
  if (
    typeof interaction?.output_text === 'string'
    && interaction.output_text.length > 0
  ) {
    return interaction.output_text;
  }

  const steps = Array.isArray(record?.steps)
    ? record.steps
    : Array.isArray(interaction?.steps)
    ? interaction.steps
    : [];
  const text = steps
    .filter((step) => asRecord(step)?.type === 'model_output')
    .flatMap((step) => {
      const content = asRecord(step)?.content;
      return Array.isArray(content) ? content : [];
    })
    .filter((part) => asRecord(part)?.type === 'text')
    .map((part) => asRecord(part)?.text)
    .filter((part): part is string => typeof part === 'string')
    .join('');

  if (text.length === 0) {
    throw new GeminiOutputError();
  }
  return text;
}

function readUsage(payload: unknown): {
  inputTokenCount: number | null;
  outputTokenCount: number | null;
} {
  const record = asRecord(payload);
  const interaction = asRecord(record?.interaction);
  const usage = asRecord(record?.usage) ?? asRecord(interaction?.usage);
  return {
    inputTokenCount: readNonNegativeInteger(
      usage?.prompt_tokens ?? usage?.input_tokens ?? usage?.total_input_tokens,
    ),
    outputTokenCount: readNonNegativeInteger(
      usage?.completion_tokens
        ?? usage?.output_tokens
        ?? usage?.total_output_tokens,
    ),
  };
}

function readNonNegativeInteger(value: unknown): number | null {
  return Number.isInteger(value) && Number(value) >= 0 ? Number(value) : null;
}

function providerErrorForStatus(status: number): GeminiProviderError {
  if (status === 429) {
    return new GeminiProviderError({
      code: 'gemini_rate_limited',
      retryable: true,
      status,
    });
  }
  if (status === 408 || status === 409 || status >= 500) {
    return new GeminiProviderError({
      code: 'gemini_provider_unavailable',
      retryable: true,
      status,
    });
  }
  if (status === 400) {
    return new GeminiProviderError({
      code: 'gemini_invalid_request',
      retryable: false,
      status,
    });
  }
  if (status === 401 || status === 403) {
    return new GeminiProviderError({
      code: 'gemini_auth_failed',
      retryable: false,
      status,
    });
  }
  if (status === 404) {
    return new GeminiProviderError({
      code: 'gemini_model_not_found',
      retryable: false,
      status,
    });
  }
  return new GeminiProviderError({
    code: 'gemini_request_failed',
    retryable: false,
    status,
  });
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
