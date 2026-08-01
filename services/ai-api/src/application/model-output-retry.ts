import {
  KoreanOutputPolicyError,
  type KoreanOutputPolicyErrorCode,
} from '../domain/korean-output-policy.ts';

const nonEchoableOutputCodes = new Set<KoreanOutputPolicyErrorCode>([
  'missing_hangul',
  'foreign_script',
  'emoji',
  'unsafe_character',
]);

export function koreanOutputRejectionCode(
  error: unknown,
): KoreanOutputPolicyErrorCode | null {
  return error instanceof KoreanOutputPolicyError ? error.code : null;
}

export function rejectedModelTextForRetry(
  value: string,
  rejectionCode: string,
): string | null {
  return nonEchoableOutputCodes.has(
      rejectionCode as KoreanOutputPolicyErrorCode,
    )
    ? null
    : value;
}
