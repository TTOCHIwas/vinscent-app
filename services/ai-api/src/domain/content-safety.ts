export type ContentSafetyKind = 'text' | 'image' | 'audio';

export type ContentSafetyPart =
  | { readonly id: string; readonly kind: 'text'; readonly text: string }
  | { readonly id: string; readonly kind: 'image' | 'audio'; readonly mimeType: string; readonly bytes: Uint8Array };

export type ContentSafetyDecision = 'allow' | 'block';
export type ContentSafetyVerdict = {
  readonly status: 'allowed' | 'blocked' | 'unavailable';
  readonly blockedPartIds: readonly string[];
};

export function contentSafetyPartsAreValid(parts: readonly ContentSafetyPart[]): boolean {
  if (parts.length === 0) return false;
  const ids = new Set<string>();
  for (const part of parts) {
    if (typeof part.id !== 'string' || part.id.trim().length === 0 || ids.has(part.id)) return false;
    ids.add(part.id);
    if (part.kind === 'text') {
      if (typeof part.text !== 'string' || part.text.trim().length === 0) return false;
    } else if (part.kind === 'image' || part.kind === 'audio') {
      if (!(part.bytes instanceof Uint8Array) || part.bytes.byteLength === 0) return false;
      if (typeof part.mimeType !== 'string' || !part.mimeType.startsWith(`${part.kind}/`)) return false;
    } else return false;
  }
  return true;
}

export function contentSafetyDecisionFrom(value: unknown): ContentSafetyDecision {
  if (value !== null && typeof value === 'object' && 'decision' in value
    && (value.decision === 'allow' || value.decision === 'block')) return value.decision;
  throw new Error('content_safety_invalid_response');
}
