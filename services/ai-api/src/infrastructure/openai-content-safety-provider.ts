import type { ContentSafetyProvider } from '../application/content-safety-port.ts';
import type { ContentSafetyPart } from '../domain/content-safety.ts';
import { isContentSafetyRecord, requestContentSafetyJson, requireContentSafetyCredential } from './content-safety-http.ts';

const requiredCategories = [
  'harassment', 'harassment/threatening', 'hate', 'hate/threatening',
  'illicit', 'illicit/violent', 'self-harm', 'self-harm/intent', 'self-harm/instructions',
  'sexual', 'sexual/minors', 'violence', 'violence/graphic',
] as const;

/** Text/image candidate. Audio and child-safety safeguards require separate coverage. */
export class OpenAiContentSafetyProvider implements ContentSafetyProvider {
  readonly supportedKinds = ['text', 'image'] as const;
  readonly #apiKey: string;
  readonly #fetcher: typeof fetch;

  constructor(options: { apiKey: string; fetcher?: typeof fetch }) {
    this.#apiKey = requireContentSafetyCredential(options.apiKey);
    this.#fetcher = options.fetcher ?? fetch;
  }

  async check(part: ContentSafetyPart, signal: AbortSignal): Promise<{ decision: 'allow' | 'block' }> {
    let input;
    if (part.kind === 'text' && part.text.trim().length > 0) {
      input = [{ type: 'text', text: part.text }];
    } else if (part.kind === 'image' && ['image/png', 'image/jpeg', 'image/webp'].includes(part.mimeType)
      && part.bytes.byteLength > 0 && part.bytes.byteLength <= 20 * 1024 * 1024) {
      // Deno and Node support btoa; avoid a Node-only Buffer dependency in Edge code.
      const chunks: string[] = [];
      for (let i = 0; i < part.bytes.length; i += 8_192) {
        chunks.push(String.fromCharCode(...part.bytes.subarray(i, i + 8_192)));
      }
      input = [{ type: 'image_url', image_url: { url: `data:${part.mimeType};base64,${btoa(chunks.join(''))}` } }];
    } else throw new Error('content_safety_unsupported_kind');
    const body = await requestContentSafetyJson({
      endpoint: 'https://api.openai.com/v1/moderations', token: this.#apiKey,
      body: { model: 'omni-moderation-latest', input }, signal, fetcher: this.#fetcher,
    });
    if (!isContentSafetyRecord(body) || !Array.isArray(body.results) || body.results.length !== 1) {
      throw new Error('content_safety_invalid_response');
    }
    const result = body.results[0];
    if (!isContentSafetyRecord(result) || typeof result.flagged !== 'boolean') {
      throw new Error('content_safety_invalid_response');
    }
    const categories = result.categories;
    if (!isContentSafetyRecord(categories)
      || requiredCategories.some((key) => typeof categories[key] !== 'boolean')
      || Object.values(categories).some((v) => typeof v !== 'boolean')) {
      throw new Error('content_safety_invalid_response');
    }
    return { decision: result.flagged || Object.values(categories).some((v) => v === true) ? 'block' : 'allow' };
  }
}
