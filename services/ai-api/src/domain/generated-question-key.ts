export type GeneratedQuestionKeyNamespace =
  | 'general_generated'
  | 'personalized_generated'
  | 'direct_follow_up_generated';

export function buildGeneratedQuestionKey(
  namespace: GeneratedQuestionKeyNamespace,
  questionText: string,
): string {
  const normalizedText = questionText.normalize('NFKC').trim();
  if (normalizedText.length === 0) {
    throw new TypeError('Generated question text is required');
  }

  let hash = 2166136261;
  for (const character of normalizedText) {
    hash ^= character.codePointAt(0) ?? 0;
    hash = Math.imul(hash, 16777619);
  }
  const suffix = (hash >>> 0)
    .toString(36)
    .padStart(8, '0')
    .slice(-8);
  return `${namespace}_${suffix}`;
}
