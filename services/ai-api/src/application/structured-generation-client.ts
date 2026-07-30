import type {
  LearningModelUsage,
} from './learning-model-port.ts';

export interface StructuredGenerationRequest {
  prompt: string;
  schema: Record<string, unknown>;
}

export interface StructuredGenerationResult {
  value: unknown;
  usage: LearningModelUsage;
}

export type StructuredGenerationErrorCode =
  | 'rate_limited'
  | 'provider_unavailable'
  | 'invalid_request'
  | 'auth_failed'
  | 'model_not_found'
  | 'request_failed'
  | 'timeout'
  | 'network_error'
  | 'content_blocked'
  | 'invalid_output';

export class StructuredGenerationError extends Error {
  readonly code: StructuredGenerationErrorCode;
  readonly retryable: boolean;
  readonly providerHttpStatus: number | null;
  readonly providerErrorStatus: string | null;
  readonly diagnosticDetail: string | null;
  readonly retryAfterMs: number | null;
  readonly usage: LearningModelUsage;

  constructor(params: {
    code: StructuredGenerationErrorCode;
    retryable: boolean;
    providerHttpStatus?: number | null;
    providerErrorStatus?: string | null;
    diagnosticDetail?: string | null;
    retryAfterMs?: number | null;
    usage?: LearningModelUsage;
    cause?: unknown;
  }) {
    super(`structured_generation_${params.code}`, { cause: params.cause });
    this.name = 'StructuredGenerationError';
    this.code = params.code;
    this.retryable = params.retryable;
    this.providerHttpStatus = params.providerHttpStatus ?? null;
    this.providerErrorStatus = params.providerErrorStatus ?? null;
    this.diagnosticDetail = params.diagnosticDetail ?? null;
    this.retryAfterMs = params.retryAfterMs ?? null;
    this.usage = params.usage ?? {
      inputTokenCount: null,
      outputTokenCount: null,
      latencyMs: 0,
    };
  }
}

export interface StructuredGenerationClient {
  generateStructured(
    request: StructuredGenerationRequest,
  ): Promise<StructuredGenerationResult>;
}
