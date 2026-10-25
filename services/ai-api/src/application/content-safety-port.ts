import type { ContentSafetyKind, ContentSafetyPart, ContentSafetyVerdict } from '../domain/content-safety.ts';

export interface ContentSafetyProvider {
  readonly supportedKinds: readonly ContentSafetyKind[];
  check(part: ContentSafetyPart, signal: AbortSignal): Promise<unknown>;
}

export type ContentSafetyClaim = {
  readonly id: string;
  readonly token: string;
  readonly parts: readonly ContentSafetyPart[];
};

export interface ContentSafetyGateway {
  /** Authenticate ownership/consent and load an immutable server-side snapshot. */
  prepare(userId: string, submissionId: string): Promise<ContentSafetyClaim | null>;
  /** Compare the claim revision and recheck ownership/relationship before recording a result. */
  complete(id: string, token: string, verdict: ContentSafetyVerdict): Promise<boolean>;
}
