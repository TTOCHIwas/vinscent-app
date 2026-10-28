import { requestContentSafetyJson, requireContentSafetyCredential } from '../../src/infrastructure/content-safety-http.ts';
import { contextInstructions, contextLimits, contextModels, contextRecord, contextRequestConfiguration,
  parseContextClassification, parseContextUsage, parseResolvedContextModel, requireContextText } from './context-policy.ts';

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
      if (!contextRecord(payload) || payload.status !== 'completed' || payload.error != null || !Array.isArray(payload.output)
        || payload.output.some(v => !contextRecord(v) || typeof v.type !== 'string' || !['message', 'reasoning'].includes(v.type))) throw new Error();
      const messages = payload.output.filter(v => v.type === 'message');
      if (messages.length !== 1 || messages[0].role !== 'assistant' || messages[0].status !== 'completed'
        || !Array.isArray(messages[0].content) || messages[0].content.length !== 1) throw new Error();
      const content = messages[0].content[0];
      if (!contextRecord(content) || content.type !== 'output_text' || typeof content.text !== 'string' || content.text.length > 8192) throw new Error();
      const usage = payload.usage == null ? { inputTokens: null, outputTokens: null }
        : contextRecord(payload.usage) ? { inputTokens: payload.usage.input_tokens, outputTokens: payload.usage.output_tokens } : undefined;
      return { classification: parseContextClassification(JSON.parse(content.text), text),
        resolvedModel: parseResolvedContextModel(payload.model, this.#model), usage: parseContextUsage(usage) };
    } catch { throw new Error('context_candidate_unavailable'); }
  }
}
