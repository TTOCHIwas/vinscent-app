export type KoreanOutputPolicyErrorCode =
  | 'missing_hangul'
  | 'foreign_script'
  | 'emoji'
  | 'unsafe_character';

export class KoreanOutputPolicyError extends Error {
  readonly code: KoreanOutputPolicyErrorCode;

  constructor(
    code: KoreanOutputPolicyErrorCode,
    label: string,
  ) {
    super(koreanOutputPolicyErrorMessage(code, label));
    this.name = 'KoreanOutputPolicyError';
    this.code = code;
  }
}

const hangulPattern = /\p{Script=Hangul}/u;
const foreignLetterPattern =
  /(?![\p{Script=Hangul}\p{Script=Latin}])\p{Letter}/u;
const emojiPattern = /\p{Extended_Pictographic}/u;
const unsafeCharacterPattern = /[\p{Cc}\p{Cf}\p{Cs}\p{Co}\p{Cn}]/u;

export function normalizeAndValidateKoreanOutput(
  value: string,
  label: string,
): string {
  const normalized = value.normalize('NFC');

  if (emojiPattern.test(normalized)) {
    throw new KoreanOutputPolicyError('emoji', label);
  }
  if (unsafeCharacterPattern.test(normalized)) {
    throw new KoreanOutputPolicyError('unsafe_character', label);
  }
  if (!hangulPattern.test(normalized)) {
    throw new KoreanOutputPolicyError('missing_hangul', label);
  }
  if (foreignLetterPattern.test(normalized)) {
    throw new KoreanOutputPolicyError('foreign_script', label);
  }

  return normalized;
}

function koreanOutputPolicyErrorMessage(
  code: KoreanOutputPolicyErrorCode,
  label: string,
): string {
  switch (code) {
    case 'missing_hangul':
      return `${label} must contain Korean text`;
    case 'foreign_script':
      return `${label} cannot contain a foreign script`;
    case 'emoji':
      return `${label} cannot contain emoji`;
    case 'unsafe_character':
      return `${label} cannot contain unsafe control characters`;
  }
}
