import { createHash } from 'node:crypto';
import { contextLimits, contextModels } from './context-policy.ts';
import { createContextExpansionExperiment, requireExpansionExperiment, buildExpansionRequest, type ContextExpansionExperiment } from './context-expansion-experiment.ts';

const hash = (v: unknown) => createHash('sha256').update(JSON.stringify(v)).digest('hex');
export function createExpansionEvaluationPlan(selection = 'both', experiment: ContextExpansionExperiment = createContextExpansionExperiment()) {
  requireExpansionExperiment(experiment);
  if (typeof selection !== 'string' || !['luna', 'terra', 'both'].includes(selection)) throw new Error('invalid_context_expansion_selection');
  const ids = selection === 'both' ? ['luna', 'terra'] as const : [selection as 'luna' | 'terra'];
  const models = ids.map(id => ({ id, model: contextModels[id], inputUsdPerMillion: id === 'luna' ? 0.1 : 1,
    cacheWriteUsdPerMillion: id === 'luna' ? 0.125 : 1.25, outputUsdPerMillion: id === 'luna' ? 0.5 : 5 }));
  const estimate = (input: number) => Number(models.reduce((sum, m) => sum + experiment.cases.length
    * (input * m.cacheWriteUsdPerMillion + contextLimits.maxOutputTokens * m.outputUsdPerMillion) / 1_000_000, 0).toFixed(9));
  const maximumSerializedRequestBytes = Math.max(...models.flatMap(m => experiment.cases.map(c => Buffer.byteLength(JSON.stringify(buildExpansionRequest(m.model, c.text, experiment)), 'utf8'))));
  const plan = { schemaVersion: 1, protocolRevision: 1, scope: 'synthetic_context_expansion_text_only',
    policyVersion: experiment.policyVersion, policyStatus: 'proposal', packSha256: experiment.packSha256,
    policySha256: hash(experiment.instructions), schemaSha256: hash(experiment.responseSchema), requestConfigurationSha256: hash(experiment.requestConfiguration),
    models, executionOrder: 'case_major_candidate_order', inputs: { syntheticTextCases: 28, scoredCasesPerCandidate: 24,
      unresolvedCasesPerCandidate: 4, imagesSent: 0, audioSent: 0,
      inventory: experiment.cases.map(c => ({ id: c.id, inputSha256: hash(c.text), scored: c.expected !== null })) },
    limits: { maximumRequests: models.length * 28, retries: 0, perCaseTimeoutMs: contextLimits.timeoutMs,
      maxTextBytes: contextLimits.maxTextBytes, maxRequestBytes: contextLimits.maxRequestBytes,
      maxOutputTokens: contextLimits.maxOutputTokens, observedInputTokensLimit: 10_000 },
    maximumSerializedRequestBytes,
    requestSettings: { endpoint: 'https://api.openai.com/v1/responses', store: false, reasoningEffort: 'none', serviceTier: 'default', tools: [] },
    estimatedUsd: estimate(2000), conservativeEstimatedUsd: estimate(10_000),
    estimateAssumptions: '28 calls/model; 2000 input tokens/call, conservative 10000; 512 output tokens/call; input charged at 1.25x cache-write allowance; excludes taxes; not a hard billing cap',
    humanLabelReviewsCompleted: 0, independentlyValidated: false, ready: false, productionPublicationAuthorized: false,
    humanListeningPerformed: false, originalAudioCovered: false };
  return { ...plan, approvalFingerprint: hash(plan) };
}

export function createExpansionRequestBudget(maximumRequests: number, fetcher: typeof fetch = fetch) {
  if (maximumRequests !== 28 && maximumRequests !== 56) throw new Error('invalid_context_expansion_budget');
  const diagnostics: { status: number | null; failure: string | null }[] = [];
  let stopped = false;
  const budgeted: typeof fetch = async (url, init) => {
    if (stopped || diagnostics.length >= maximumRequests) throw new Error('context_expansion_budget_stopped');
    const entry = { status: null as number | null, failure: null as string | null }; diagnostics.push(entry);
    try {
      const response = await fetcher(url, init); entry.status = response.status;
      if (!response.ok) { stopped = true; entry.failure = 'http_error'; }
      return response;
    } catch { stopped = true; entry.failure = 'transport_error'; throw new Error('context_candidate_unavailable'); }
  };
  return { fetcher: budgeted, diagnostics, isStopped: () => stopped };
}
