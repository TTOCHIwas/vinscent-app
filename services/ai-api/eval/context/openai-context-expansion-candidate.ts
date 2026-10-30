import { requestContentSafetyJson, requireContentSafetyCredential } from '../../src/infrastructure/content-safety-http.ts';
import { contextModels } from './context-policy.ts';
import { buildExpansionRequest, parseExpansionClassification, requireExpansionExperiment, type ContextExpansionExperiment } from './context-expansion-experiment.ts';
import { readContextObservation } from './context-response.ts';

export class OpenAiContextExpansionCandidate {
  readonly #key: string;
  readonly #model: string;
  readonly #experiment: ContextExpansionExperiment;
  readonly #fetcher: typeof fetch;
  constructor(options: { apiKey: string; model: string; experiment: ContextExpansionExperiment; fetcher?: typeof fetch }) {
    this.#key = requireContentSafetyCredential(options.apiKey);
    if (!(Object.values(contextModels) as string[]).includes(options.model)) throw new Error('invalid_context_expansion_model');
    requireExpansionExperiment(options.experiment);
    this.#model = options.model; this.#experiment = options.experiment; this.#fetcher = options.fetcher ?? fetch;
  }
  async classify(text: string, signal: AbortSignal) {
    try {
      signal.throwIfAborted();
      const body = buildExpansionRequest(this.#model, text, this.#experiment);
      const payload = await requestContentSafetyJson({ endpoint: 'https://api.openai.com/v1/responses', token: this.#key,
        body, signal, fetcher: this.#fetcher });
      signal.throwIfAborted();
      const observation = readContextObservation(payload, this.#model);
      return { ...observation, classification: parseExpansionClassification(observation.classification, text) };
    } catch { throw new Error('context_candidate_unavailable'); }
  }
}
