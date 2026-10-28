import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluateContextCandidates } from '../eval/context/context-evaluation.ts';
import { createContextEvaluationPlan } from '../eval/context/context-evaluation-plan.ts';
import { contextPolicyVersion } from '../eval/context/context-policy.ts';
import { contentSafetyContextCases } from '../eval/fixtures/content-safety-context-ko.ts';

const observation = (text: string, decision = 'allow', intent = 'benign') => ({
  classification: { policy_version: contextPolicyVersion, decision, intent, evidence: [text] },
  resolvedModel: 'gpt-6-luna', usage: { inputTokens: 100, outputTokens: 20 },
});

test('candidate plans bind corpus, policy, schema, settings and exact selected models before paid calls', () => {
  const both = createContextEvaluationPlan('both');
  assert.equal(both.limits.maximumRequests, 24);
  assert.equal(both.inputs.scoredCasesPerCandidate, 10);
  assert.equal(both.inputs.unresolvedCasesPerCandidate, 2);
  assert.equal(both.limits.retries, 0);
  assert.equal(both.limits.maxOutputTokens, 512);
  assert.equal(both.inputs.imagesSent, 0);
  assert.equal(both.inputs.audioSent, 0);
  assert(Math.abs(both.estimatedUsd - 0.066792) < 1e-10);
  assert(Math.abs(both.conservativeEstimatedUsd - 0.198792) < 1e-10);
  assert.notEqual(both.approvalFingerprint, createContextEvaluationPlan('luna').approvalFingerprint);
  assert.notEqual(createContextEvaluationPlan('luna').approvalFingerprint, createContextEvaluationPlan('terra').approvalFingerprint);
  assert.equal(createContextEvaluationPlan('luna').limits.maximumRequests, 12);
  assert.throws(() => createContextEvaluationPlan('other' as 'both'));
});

test('simulation separates ten draft labels from two unresolved cases and never fabricates publication readiness', async () => {
  const used: string[] = [];
  const report = await evaluateContextCandidates({ cases: contentSafetyContextCases, candidates: [{ id: 'luna', model: 'gpt-6-luna',
    port: { classify: async (text: string) => {
      used.push(text);
      const sample = contentSafetyContextCases.find(c => c.text === text)!;
      const intent = sample.expected === 'block' ? 'coercion' : sample.expected === 'unavailable' ? 'unresolved_context' : 'benign';
      return observation(text, sample.expected, intent);
    } } }] });
  assert.equal(report.models[0].scoredCases, 10);
  assert.equal(report.models[0].correct, 10);
  assert.equal(report.models[0].unresolvedCases, 2);
  assert.equal(report.productionPublicationAuthorized, false);
  assert.equal(report.ready, false);
  assert.equal(report.scope, 'synthetic_context_text_only');
  assert.equal(used.length, 12);
  assert.equal(JSON.stringify(report).includes(contentSafetyContextCases[0].text), false);
});

test('unresolved model allows remain visible and are not converted into expected unavailable answers', async () => {
  const report = await evaluateContextCandidates({ cases: contentSafetyContextCases, candidates: [{ id: 'luna', model: 'gpt-6-luna',
    port: { classify: async (text: string) => observation(text) } }] });
  assert.equal(report.models[0].unresolvedModelAllows, 2);
  assert.equal(report.results.find(r => r.id === 'victim-report')?.actual, 'allow');
  assert.equal(report.models[0].falseAllows, 6);
  assert.equal(report.ready, false);
});

test('invalid schema and timeout stop the entire run instead of continuing or retrying', async () => {
  for (const classify of [async (_text: string, _signal: AbortSignal): Promise<unknown> => ({ classification: {} }),
    async (_text: string, _signal: AbortSignal): Promise<unknown> => new Promise(() => {})]) {
    let calls = 0;
    const report = await evaluateContextCandidates({ cases: contentSafetyContextCases, timeoutMs: 5, candidates: [{ id: 'luna', model: 'gpt-6-luna',
      port: { classify: async (text: string, signal: AbortSignal) => { calls++; return classify(text, signal); } } }] });
    assert.equal(calls, 1);
    assert.equal(report.stoppedOnOperationalFailure, true);
    assert.equal(report.results[0].actual, 'unavailable');
    assert.equal(report.results[0].operationalStatus, 'failed');
  }
});

test('empty or duplicate cases and candidates are rejected before model calls', async () => {
  const candidate = { id: 'luna', model: 'gpt-6-luna', port: { classify: async () => { throw new Error('unexpected'); } } };
  await assert.rejects(evaluateContextCandidates({ cases: [], candidates: [candidate] }));
  await assert.rejects(evaluateContextCandidates({ cases: [...contentSafetyContextCases, contentSafetyContextCases[0]], candidates: [candidate] }));
  await assert.rejects(evaluateContextCandidates({ cases: contentSafetyContextCases, candidates: [candidate, candidate] }));
});
