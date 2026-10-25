import { contentSafetyDecisionFrom, contentSafetyPartsAreValid } from '../domain/content-safety.ts';
import type { ContentSafetyVerdict } from '../domain/content-safety.ts';
import type { ContentSafetyGateway, ContentSafetyProvider } from './content-safety-port.ts';

/** Records a classification only. Publishing requires a separate atomic server-side gate. */
export class CheckSharedContent {
  readonly #gateway: ContentSafetyGateway;
  readonly #provider: ContentSafetyProvider;
  readonly #timeoutMs: number;

  constructor(options: { gateway: ContentSafetyGateway; provider: ContentSafetyProvider; timeoutMs?: number }) {
    this.#gateway = options.gateway;
    this.#provider = options.provider;
    this.#timeoutMs = options.timeoutMs ?? 15_000;
    if (!Number.isSafeInteger(this.#timeoutMs) || this.#timeoutMs <= 0) throw new TypeError('invalid content safety timeout');
  }

  async execute(userId: string, submissionId: string): Promise<ContentSafetyVerdict['status'] | 'stale'> {
    let claim;
    try { claim = await this.#gateway.prepare(userId, submissionId); }
    catch { return 'unavailable'; }
    if (claim === null) return 'unavailable';
    let verdict: ContentSafetyVerdict = { status: 'unavailable', blockedPartIds: [] };
    if (contentSafetyPartsAreValid(claim.parts)
      && claim.parts.every((part) => this.#provider.supportedKinds.includes(part.kind))) {
      const controller = new AbortController();
      let timer: ReturnType<typeof setTimeout> | undefined;
      try {
        const checks = async (): Promise<ContentSafetyVerdict> => {
          const blockedPartIds: string[] = [];
          for (const part of claim.parts) {
            controller.signal.throwIfAborted();
            const decision = contentSafetyDecisionFrom(await this.#provider.check(part, controller.signal));
            if (decision === 'block') blockedPartIds.push(part.id);
          }
          return { status: blockedPartIds.length > 0 ? 'blocked' : 'allowed', blockedPartIds };
        };
        const deadline = new Promise<never>((_resolve, reject) => {
          timer = setTimeout(() => {
            controller.abort();
            reject(new Error('content_safety_timeout'));
          }, this.#timeoutMs);
        });
        verdict = await Promise.race([checks(), deadline]);
      } catch {
        // Unsupported, malformed, timed-out and failed checks never approve content.
      } finally {
        clearTimeout(timer);
        controller.abort();
      }
    }
    try {
      return await this.#gateway.complete(claim.id, claim.token, verdict) ? verdict.status : 'stale';
    } catch { return 'unavailable'; }
  }
}
