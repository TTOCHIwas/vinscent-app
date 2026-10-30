import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { createContextResumeSession, createContextResumePlan, evaluateContextResume } from '../eval/context/context-resume.ts';
import { evaluateContextExpansion } from '../eval/context/context-expansion-evaluation.ts';

const original = JSON.parse(readFileSync('../../docs/release/content-safety-context-v2-evaluation-2026-10-30/openai.json', 'utf8').replace(/^\uFEFF/, ''));
const session = createContextResumeSession(original);
function simulatedCandidates(calls: string[], unavailableAsAllow = false, fail: 'schema' | 'timeout' | null = null) {
  return ['luna', 'terra'].map(id => ({ id, model: id === 'luna' ? 'gpt-6-luna' : 'gpt-6.1-terra',
    port: { classify: async (text: string) => {
      const c = session.experiment.cases.find(c => c.text === text)!; calls.push(`${c.id}:${id}`);
      if (fail === 'schema') return {};
      if (fail === 'timeout') return new Promise(() => {});
      const decision = c.expected ?? (unavailableAsAllow ? 'allow' : 'unavailable');
      return { classification: { policy_version: session.experiment.policyVersion, decision,
        intent: decision === 'block' ? 'coercion' : decision === 'allow' ? 'benign' : 'unresolved_context', evidence: [text] },
        resolvedModel: id === 'luna' ? 'gpt-6-luna' : 'gpt-6.1-terra', usage: { inputTokens: 100, outputTokens: 30 } };
    } } }));
}

test('resume plan selects one prior failure and 27 unattempted requests, excludes all completed requests and binds source', () => {
  const plan = createContextResumePlan(session);
  assert.equal(plan.priorActualRequests, 29); assert.equal(plan.priorSuccessfulRequests, 28);
  assert.equal(plan.limits.maximumRequests, 28); assert.equal(plan.maximumCumulativeRequests, 57);
  assert.equal(plan.retryPolicy.priorFailedRequestsToRetry, 1); assert.equal(plan.retryPolicy.automaticRetries, 0);
  assert.equal(plan.unattemptedRequests, 27);
  assert.equal(plan.estimatedUsd, 0.077924); assert.equal(plan.conservativeEstimatedUsd, 0.231924);
  assert.equal(plan.sourceReportCanonicalSha256, 'f66d09d26fa3e3c30a8701d34ee2ced69dc8f8e113bc7d4a1b75f6effe1a6894');
  assert.equal(plan.remaining.length, 28);
  assert.deepEqual(session.requests[0], { id: 'expand-benign-03', candidate: 'luna' });
  for (const r of original.results.filter((r: any) => r.operationalStatus === 'completed'))
    assert(!session.requests.some(q => q.id === r.id && q.candidate === r.candidate));
  assert.throws(() => { (session.requests as any).push(session.requests[0]); });
  assert.throws(() => createContextResumePlan(structuredClone(session)));
});

for (const [name, mutate] of [
  ['changed label', (r: any) => { r.results[0].expected = 'allow'; }],
  ['changed result', (r: any) => { r.results[0].actual = 'allow'; }],
  ['missing row', (r: any) => { r.results.pop(); }],
  ['duplicate row', (r: any) => { r.results.push(r.results[0]); }],
  ['changed model', (r: any) => { r.plan.models[0].model = 'unapproved'; }],
  ['changed request count', (r: any) => { r.actualRequests = 28; }],
  ['changed HTTP status', (r: any) => { r.diagnostics[28].status = 200; }],
  ['changed policy', (r: any) => { r.policyVersion = 'other'; }],
  ['changed timestamp', (r: any) => { r.generatedAt = '2026-10-30T00:00:00.000Z'; }],
] as const) test(`${name} cannot become an approved resume source`, () => {
  const r = structuredClone(original); mutate(r); assert.throws(() => createContextResumeSession(r), /invalid_context_resume_source/);
});

test('simulated resume executes exactly the remaining 28 calls and combines observed coverage without changing original evidence', async () => {
  const before = JSON.stringify(original); const calls: string[] = [];
  const r = await evaluateContextResume({ session, candidates: simulatedCandidates(calls) });
  assert.equal(calls.length, 28); assert.equal(new Set(calls).size, 28);
  assert.deepEqual(calls, session.requests.map(q => `${q.id}:${q.candidate}`));
  assert.equal(r.additionalEvaluation.results.length, 28);
  assert.equal(r.combined.successfulObservations, 56); assert.equal(r.combined.coverageComplete, true);
  assert.equal(r.combined.cumulativeEvaluationAttempts, 57); assert.equal(r.combined.priorFailedAttempts, 1);
  assert.equal(r.combined.models[0].correct, 24); assert.equal(r.combined.models[0].unresolvedObserved, 4);
  assert.equal(r.combined.results.filter(r => r.source === 'prior').length, 28);
  assert.equal(r.combined.results.filter(r => r.source === 'resume').length, 28);
  assert.equal(r.combined.ready, false); assert.equal(r.combined.productionPublicationAuthorized, false);
  assert.equal(r.combined.independentlyValidated, false); assert.equal(JSON.stringify(original), before);
});

test('unlabelled model allows remain visible after combining, without fabricated expected answers', async () => {
  const r = await evaluateContextResume({ session, candidates: simulatedCandidates([], true) });
  assert.equal(r.combined.models[0].unresolvedModelAllows, 4);
  assert(r.combined.results.filter(r => r.expected === null).every(r => r.actual === 'allow'));
  assert.equal(r.combined.ready, false);
});

for (const fail of ['schema', 'timeout'] as const) test('repeat operational failure stops remaining work and cannot fabricate full coverage', async () => {
  const calls: string[] = [];
  const r = await evaluateContextResume({ session, candidates: simulatedCandidates(calls, false, fail), timeoutMs: 5 });
  assert.equal(calls.length, 1); assert.equal(r.additionalEvaluation.results[0].actual, 'unavailable');
  assert.equal(r.combined.successfulObservations, 28); assert.equal(r.combined.pendingObservations, 28);
  assert.equal(r.combined.coverageComplete, false); assert.equal(r.combined.cumulativeEvaluationAttempts, 30);
  assert.equal(r.combined.additionalFailedAttempts, 1);
});

test('subset engine rejects duplicated, unknown, reversed or coercible queue entries before requests', async () => {
  const candidates = simulatedCandidates([]);
  for (const requests of [[], [session.requests[0], session.requests[0]], [{ id: 'unknown', candidate: 'luna' }],
    [session.requests[1], session.requests[0]], [{ ...session.requests[0], candidate: ['luna'] }]])
    await assert.rejects(evaluateContextExpansion({ experiment: session.experiment, candidates, requests: requests as any }));
  await assert.rejects(evaluateContextResume({ session, candidates: [candidates[0]] }));
});
