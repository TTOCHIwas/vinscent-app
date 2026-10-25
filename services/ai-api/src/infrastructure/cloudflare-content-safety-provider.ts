import type { ContentSafetyProvider } from '../application/content-safety-port.ts';
import type { ContentSafetyPart } from '../domain/content-safety.ts';
import { isContentSafetyRecord, requestContentSafetyJson, requireContentSafetyCredential } from './content-safety-http.ts';

/** Text-only comparison candidate; never use it to implicitly approve media. */
export class CloudflareContentSafetyProvider implements ContentSafetyProvider {
  readonly supportedKinds = ['text'] as const;
  readonly #accountId: string;
  readonly #apiToken: string;
  readonly #fetcher: typeof fetch;

  constructor(options: { accountId: string; apiToken: string; fetcher?: typeof fetch }) {
    if (!/^[a-f0-9]{32}$/i.test(options.accountId)) throw new TypeError('invalid Cloudflare account ID');
    this.#accountId = options.accountId;
    this.#apiToken = requireContentSafetyCredential(options.apiToken);
    this.#fetcher = options.fetcher ?? fetch;
  }

  async check(part: ContentSafetyPart, signal: AbortSignal): Promise<{ decision: 'allow' | 'block' }> {
    if (part.kind !== 'text' || part.text.trim().length === 0) throw new Error('content_safety_unsupported_kind');
    const body = await requestContentSafetyJson({
      endpoint: `https://api.cloudflare.com/client/v4/accounts/${this.#accountId}/ai/run/@cf/meta/llama-guard-3-8b`,
      token: this.#apiToken, body: { messages: [{ role: 'user', content: part.text }], temperature: 0, max_tokens: 128 },
      signal, fetcher: this.#fetcher,
    });
    if (!isContentSafetyRecord(body) || body.success !== true || !isContentSafetyRecord(body.result)
      || typeof body.result.response !== 'string') throw new Error('content_safety_invalid_response');
    const label = body.result.response.trim();
    if (label === 'safe') return { decision: 'allow' };
    if (/^unsafe\s+S(?:[1-9]|1[0-4])(?:\s*,\s*S(?:[1-9]|1[0-4]))*$/.test(label)) return { decision: 'block' };
    throw new Error('content_safety_invalid_response');
  }
}
