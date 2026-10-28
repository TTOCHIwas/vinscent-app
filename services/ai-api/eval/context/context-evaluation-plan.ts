import { createHash } from 'node:crypto';
import { contentSafetyContextCases } from '../fixtures/content-safety-context-ko.ts';
import { contextInstructions, contextLimits, contextModels, contextPolicyVersion, contextResponseSchema, contextRequestConfiguration } from './context-policy.ts';

const hash = (v: unknown) => createHash('sha256').update(JSON.stringify(v)).digest('hex');
export function createContextEvaluationPlan(selection: string = 'both') {
  if (typeof selection !== 'string' || !['luna', 'terra', 'both'].includes(selection)) throw new TypeError('invalid_context_selection');
  const ids = selection === 'both' ? ['luna', 'terra'] as const : [selection as 'luna' | 'terra'];
  const models = ids.map(id => ({ id, model: contextModels[id], inputUsdPerMillion: id === 'luna' ? 0.1 : 1,
    cacheWriteUsdPerMillion: id === 'luna' ? 0.125 : 1.25, outputUsdPerMillion: id === 'luna' ? 0.5 : 5 }));
  const estimate = (inputTokens: number) => Number(models.reduce((sum, m) => sum
    + 12 * (inputTokens * m.cacheWriteUsdPerMillion + contextLimits.maxOutputTokens * m.outputUsdPerMillion) / 1_000_000, 0).toFixed(9));
  const plan = { schemaVersion: 1, scope: 'synthetic_context_text_only', policyVersion: contextPolicyVersion, policyStatus: 'draft',
    corpusSha256: hash(contentSafetyContextCases), policySha256: hash(contextInstructions), schemaSha256: hash(contextResponseSchema),
    requestConfigurationSha256: hash(contextRequestConfiguration),
    protocolRevision: 1, models, executionOrder: 'case_major_candidate_order',
    inputs: { syntheticTextCases: 12, scoredCasesPerCandidate: 10, unresolvedCasesPerCandidate: 2, imagesSent: 0, audioSent: 0,
      inventory: contentSafetyContextCases.map(c => ({ id: c.id, inputSha256: hash(c.text), scored: c.expected !== 'unavailable' })) },
    limits: { maximumRequests: models.length * 12, retries: 0, perCaseTimeoutMs: contextLimits.timeoutMs,
      maxTextBytes: contextLimits.maxTextBytes, maxRequestBytes: contextLimits.maxRequestBytes, maxOutputTokens: contextLimits.maxOutputTokens,
      observedInputTokensLimit: 10_000 },
    requestSettings: { endpoint: 'https://api.openai.com/v1/responses', store: false, reasoningEffort: 'none', serviceTier: 'default', tools: [] },
    estimatedUsd: estimate(2000), conservativeEstimatedUsd: estimate(10_000),
    estimateAssumptions: '12 calls/model; 2000 input tokens/call, conservative 10000; 512 output tokens/call; input charged at 1.25x as cache-write allowance; excludes taxes; not a hard billing cap',
    ready: false, productionPublicationAuthorized: false, humanListeningPerformed: false };
  return { ...plan, approvalFingerprint: hash(plan) };
}
