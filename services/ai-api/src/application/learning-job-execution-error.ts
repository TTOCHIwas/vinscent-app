import type { LearningModelUsage } from './learning-model-port.ts';

export class LearningJobExecutionError extends Error {
  readonly code: string;
  readonly retryable: boolean;
  readonly usage: LearningModelUsage;

  constructor(params: {
    code: string;
    retryable: boolean;
    usage: LearningModelUsage;
    cause?: unknown;
  }) {
    const code = requireErrorCode(params.code);
    super(code, { cause: params.cause });
    this.name = 'LearningJobExecutionError';
    this.code = code;
    this.retryable = params.retryable;
    this.usage = params.usage;
  }
}

function requireErrorCode(value: string): string {
  const normalized = value.trim();
  if (!/^[a-z0-9_]{1,160}$/u.test(normalized)) {
    throw new RangeError('learning job error code must be a valid identifier');
  }
  return normalized;
}
