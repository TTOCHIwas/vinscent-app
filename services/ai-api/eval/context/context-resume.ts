import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createContextExpansionExperiment, buildExpansionRequest } from './context-expansion-experiment.ts';
import { createExpansionEvaluationPlan } from './context-expansion-plan.ts';
import { evaluateContextExpansion } from './context-expansion-evaluation.ts';

const sourceReportCanonicalSha256 = 'f66d09d26fa3e3c30a8701d34ee2ced69dc8f8e113bc7d4a1b75f6effe1a6894';
const sessions = new WeakSet<object>();
const hash = (value: unknown) => createHash('sha256').update(JSON.stringify(value)).digest('hex');
function freeze<T>(value: T): T {
  if (value !== null && typeof value === 'object') { for (const v of Object.values(value)) freeze(v); Object.freeze(value); }
  return value;
}
type Evaluation = Awaited<ReturnType<typeof evaluateContextExpansion>>;
type Source = Evaluation & { plan: ReturnType<typeof createExpansionEvaluationPlan>; actualRequests: number };

export function createContextResumeSession(value?: unknown) {
  try {
    const raw: unknown = value === undefined ? JSON.parse(readFileSync(new URL('../../../../docs/release/content-safety-context-v2-evaluation-2026-10-30/openai.json', import.meta.url), 'utf8').replace(/^\uFEFF/, '')) : value;
    const serialized = JSON.stringify(raw);
    if (typeof serialized !== 'string' || createHash('sha256').update(serialized).digest('hex') !== sourceReportCanonicalSha256) throw new Error();
    const source = JSON.parse(serialized) as Source;
    const experiment = createContextExpansionExperiment(); const originalPlan = createExpansionEvaluationPlan('both', experiment);
    if (hash(source.plan) !== hash(originalPlan) || source.packSha256 !== experiment.packSha256) throw new Error();
    const requests = experiment.cases.flatMap(c => originalPlan.models.map(m => ({ id: c.id, candidate: m.id })))
      .filter(q => !source.results.some(r => r.id === q.id && r.candidate === q.candidate && r.operationalStatus === 'completed'));
    if (requests.length !== 28) throw new Error();
    const session = freeze({ sourceReportCanonicalSha256, source, experiment, originalPlan, requests });
    sessions.add(session); return session;
  } catch { throw new Error('invalid_context_resume_source'); }
}
export type ContextResumeSession = ReturnType<typeof createContextResumeSession>;
function requireSession(value: unknown): asserts value is ContextResumeSession {
  if (value === null || typeof value !== 'object' || !sessions.has(value)) throw new Error('invalid_context_resume_session');
}

export function createContextResumePlan(session: ContextResumeSession) {
  requireSession(session);
  const models = session.originalPlan.models.map(m => ({ ...m, additionalRequests: session.requests.filter(q => q.candidate === m.id).length }));
  const remaining = session.requests.map(q => {
    const sample = session.experiment.cases.find(c => c.id === q.id)!;
    const model = models.find(m => m.id === q.candidate)!.model;
    const priorFailure = session.source.results.some(r => r.id === q.id && r.candidate === q.candidate && r.operationalStatus === 'failed');
    return { ...q, model, inputSha256: hash(sample.text), status: priorFailure ? 'retry_failed_request' : 'not_attempted' };
  });
  const estimate = (input: number) => Number(models.reduce((sum, m) => sum + m.additionalRequests
    * (input * m.cacheWriteUsdPerMillion + 512 * m.outputUsdPerMillion) / 1_000_000, 0).toFixed(9));
  const plan = { schemaVersion: 1, protocolRevision: 1, scope: 'synthetic_context_resume_text_only',
    sourceReportCanonicalSha256: session.sourceReportCanonicalSha256, sourcePlanFingerprint: session.originalPlan.approvalFingerprint,
    policyVersion: session.experiment.policyVersion, packSha256: session.experiment.packSha256,
    policySha256: session.originalPlan.policySha256, schemaSha256: session.originalPlan.schemaSha256,
    requestConfigurationSha256: session.originalPlan.requestConfigurationSha256, requestSubsetSha256: hash(session.requests),
    executionOrder: 'original_case_major_subset', models, remaining,
    priorActualRequests: session.source.actualRequests, priorSuccessfulRequests: session.source.results.filter(r => r.operationalStatus === 'completed').length,
    unattemptedRequests: remaining.filter(r => r.status === 'not_attempted').length,
    maximumCumulativeRequests: session.source.actualRequests + remaining.length,
    retryPolicy: { priorFailedRequestsToRetry: remaining.filter(r => r.status === 'retry_failed_request').length,
      automaticRetries: 0, repeatCompletedRequests: false, stopOnFirstOperationalFailure: true },
    limits: { ...session.originalPlan.limits, maximumRequests: remaining.length },
    inputs: { syntheticTextCases: new Set(remaining.map(q => q.id)).size, scoredRequests: remaining.filter(q => session.experiment.cases.find(c => c.id === q.id)!.expected !== null).length,
      unresolvedRequests: remaining.filter(q => session.experiment.cases.find(c => c.id === q.id)!.expected === null).length, imagesSent: 0, audioSent: 0 },
    maximumSerializedRequestBytes: Math.max(...remaining.map(q => Buffer.byteLength(JSON.stringify(buildExpansionRequest(q.model,
      session.experiment.cases.find(c => c.id === q.id)!.text, session.experiment)), 'utf8'))),
    requestSettings: session.originalPlan.requestSettings, estimatedUsd: estimate(2000), conservativeEstimatedUsd: estimate(10_000),
    estimateAssumptions: '14 calls/model; 2000 input tokens/call, conservative 10000; 512 output tokens/call; input charged at 1.25x cache-write allowance; excludes taxes; not a hard billing cap',
    humanLabelReviewsCompleted: 0, independentlyValidated: false, ready: false, productionPublicationAuthorized: false,
    humanListeningPerformed: false, originalAudioCovered: false };
  return freeze({ ...plan, approvalFingerprint: hash(plan) });
}

export async function evaluateContextResume(options: { session: ContextResumeSession;
  candidates: Parameters<typeof evaluateContextExpansion>[0]['candidates']; timeoutMs?: number }) {
  requireSession(options.session); const session = options.session;
  if (!Array.isArray(options.candidates) || options.candidates.length !== session.originalPlan.models.length
    || options.candidates.some((c, i) => c.id !== session.originalPlan.models[i].id || c.model !== session.originalPlan.models[i].model)) throw new Error('invalid_context_resume_candidates');
  const additionalEvaluation = await evaluateContextExpansion({ experiment: session.experiment, candidates: options.candidates,
    requests: session.requests, timeoutMs: options.timeoutMs });
  const chosen = new Map<string, Evaluation['results'][number] & { source: string }>();
  for (const [source, rows] of [['prior', session.source.results], ['resume', additionalEvaluation.results]] as const)
    for (const row of rows) if (row.operationalStatus === 'completed') chosen.set(`${row.id}:${row.candidate}`, { ...row, source });
  const results = session.experiment.cases.flatMap(c => session.originalPlan.models.flatMap(m => {
    const row = chosen.get(`${c.id}:${m.id}`); return row ? [row] : [];
  }));
  const models = session.originalPlan.models.map(m => {
    const rows = results.filter(r => r.candidate === m.id); const scored = rows.filter(r => r.expected !== null);
    const unresolved = rows.filter(r => r.expected === null);
    return { id: m.id, model: m.model, plannedCases: 28, successfulCases: rows.length, scoredCompletedCases: scored.length,
      scoredMissingCases: 24 - scored.length, correct: scored.filter(r => r.actual === r.expected).length,
      falseAllows: scored.filter(r => r.expected === 'block' && r.actual === 'allow').length,
      falseBlocks: scored.filter(r => r.expected === 'allow' && r.actual === 'block').length,
      unavailableScored: scored.filter(r => r.actual === 'unavailable').length,
      unresolvedObserved: unresolved.length, unresolvedMissing: 4 - unresolved.length,
      unresolvedModelAllows: unresolved.filter(r => r.actual === 'allow').length };
  });
  const combined = { scope: 'combined_context_observations_across_runs', sourceReportCanonicalSha256: session.sourceReportCanonicalSha256,
    policyVersion: session.experiment.policyVersion, packSha256: session.experiment.packSha256,
    successfulObservations: results.length, pendingObservations: 56 - results.length, coverageComplete: results.length === 56,
    cumulativeEvaluationAttempts: session.source.actualRequests + additionalEvaluation.results.length,
    priorFailedAttempts: session.source.results.filter(r => r.operationalStatus === 'failed').length,
    additionalFailedAttempts: additionalEvaluation.results.filter(r => r.operationalStatus === 'failed').length,
    allScoredProposalsMatched: results.length === 56 && models.every(m => m.correct === 24),
    ready: false, productionPublicationAuthorized: false, independentlyValidated: false, humanLabelReviewsCompleted: 0,
    humanListeningPerformed: false, originalAudioCovered: false, models, results };
  return { additionalEvaluation, combined };
}
