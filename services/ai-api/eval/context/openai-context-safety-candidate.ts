import { requestContentSafetyJson, requireContentSafetyCredential } from '../../src/infrastructure/content-safety-http.ts';
import { contextInstructions, contextLimits, contextModels, contextRequestConfiguration,
  parseContextClassification, requireContextText } from './context-policy.ts';
import { readContextObservation } from './context-response.ts';

export class OpenAiContextSafetyCandidate {
  readonly #key: string;
  readonly #model: string;
  readonly #fetcher: typeof fetch;
  constructor(options: { apiKey: string; model: string; fetcher?: typeof fetch }) {
    this.#key = requireContentSafetyCredential(options.apiKey);
    if (!(Object.values(contextModels) as string[]).includes(options.model)) throw new TypeError('invalid_context_model');
    this.#model = options.model; this.#fetcher = options.fetcher ?? fetch;
  }
  async classify(text: string, signal: AbortSignal) {
    try {
      signal.throwIfAborted(); requireContextText(text);
      const body = { model: this.#model, instructions: contextInstructions,
        input: [{ role: 'user', content: [{ type: 'input_text', text: JSON.stringify({ text }) }] }],
        ...contextRequestConfiguration };
      if (Buffer.byteLength(JSON.stringify(body), 'utf8') > contextLimits.maxRequestBytes) throw new Error();
      const payload = await requestContentSafetyJson({ endpoint: 'https://api.openai.com/v1/responses',
        token: this.#key, body, signal, fetcher: this.#fetcher });
      signal.throwIfAborted();
      const observation = readContextObservation(payload, this.#model);
      return { ...observation, classification: parseContextClassification(observation.classification, text) };
    } catch { throw new Error('context_candidate_unavailable'); }
  }
}
