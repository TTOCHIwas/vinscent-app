import assert from 'node:assert/strict';
import test from 'node:test';
import { createContextExpansionExperiment } from '../eval/context/context-expansion-experiment.ts';
import { createExpansionEvaluationPlan, createExpansionRequestBudget } from '../eval/context/context-expansion-plan.ts';
import { evaluateContextExpansion } from '../eval/context/context-expansion-evaluation.ts';
import { createContextEvaluationPlan } from '../eval/context/context-evaluation-plan.ts';

const experiment = createContextExpansionExperiment();
const mock = (id = 'luna', unknownAllow = false) => ({ id, model: id === 'luna' ? 'gpt-6-luna' : 'gpt-6.1-terra',
  port: { classify: async (text: string) => {
    const c = experiment.cases.find(c => c.text === text)!;
    const decision = c.expected ?? (unknownAllow ? 'allow' : 'unavailable');
    return { classification: { policy_version: experiment.policyVersion, decision,
      intent: decision === 'block' ? 'coercion' : decision === 'allow' ? 'benign' : 'unresolved_context', evidence: [text] },
      resolvedModel: id === 'luna' ? 'gpt-6-luna' : 'gpt-6.1-terra', usage: { inputTokens: 100, outputTokens: 30 } };
  } } });

test('v2 plan counts 28/56 requests and binds policy, corpus, protocol, models, limits and cost assumptions', () => {
  const both = createExpansionEvaluationPlan('both', experiment);
  assert.equal(both.limits.maximumRequests, 56); assert.equal(both.inputs.syntheticTextCases, 28);
  assert.equal(both.inputs.scoredCasesPerCandidate, 24); assert.equal(both.inputs.unresolvedCasesPerCandidate, 4);
  assert.equal(both.limits.retries, 0); assert.equal(both.inputs.imagesSent, 0); assert.equal(both.inputs.audioSent, 0);
  assert.equal(both.estimatedUsd, 0.155848); assert.equal(both.conservativeEstimatedUsd, 0.463848);
  assert.equal(createExpansionEvaluationPlan('luna').limits.maximumRequests, 28);
  assert.notEqual(both.approvalFingerprint, createExpansionEvaluationPlan('terra').approvalFingerprint);
  assert.notEqual(both.approvalFingerprint, createContextEvaluationPlan().approvalFingerprint);
  assert.equal(createContextEvaluationPlan().limits.maximumRequests, 24);
  assert.equal(both.independentlyValidated, false); assert.equal(both.ready, false);
  assert.throws(() => createExpansionEvaluationPlan('bad'));
});

test('simulation scores 24 proposals separately from four unlabelled cases without claiming quality or readiness', async () => {
  const r = await evaluateContextExpansion({ experiment, candidates: [mock(), mock('terra')] });
  assert.equal(r.results.length, 56); assert.equal(r.models[0].scoredCases, 24); assert.equal(r.models[0].correct, 24);
  assert.equal(r.models[0].unresolvedCases, 4); assert.equal(r.allScoredProposalsMatched, true);
  assert.equal(r.ready, false); assert.equal(r.productionPublicationAuthorized, false); assert.equal(r.independentlyValidated, false);
  assert.equal(r.humanListeningPerformed, false); assert.equal(r.originalAudioCovered, false);
  assert(!JSON.stringify(r).includes(experiment.cases[0].text));
});

test('unlabelled model allows remain observed allows with expected null', async () => {
  const r = await evaluateContextExpansion({ experiment, candidates: [mock('luna', true)] });
  assert.equal(r.models[0].unresolvedModelAllows, 4);
  assert(r.results.filter(c => c.expected === null).every(c => c.actual === 'allow'));
  assert.equal(r.ready, false);
});

for (const timeout of [false, true]) test('operational failure stops both candidates and all remaining cases without retry', async () => {
  let calls = 0;
  const bad = { ...mock(), port: { classify: async () => { calls++; return timeout ? new Promise(() => {}) : {}; } } };
  const r = await evaluateContextExpansion({ experiment, candidates: [bad, mock('terra')], timeoutMs: 5 });
  assert.equal(calls, 1); assert.equal(r.results.length, 1); assert.equal(r.results[0].actual, 'unavailable');
  assert.equal(r.stoppedOnOperationalFailure, true); assert.equal(r.allScoredProposalsMatched, false);
});

test('invalid or duplicate candidates cannot issue requests', async () => {
  for (const candidates of [[], [mock(), mock()], [{ ...mock(), id: ['luna'] }], [{ ...mock(), model: 'unapproved' }]]) {
    await assert.rejects(evaluateContextExpansion({ experiment, candidates: candidates as any }));
  }
});

test('v2 independently rejects invalid observed model/usage and counts proposal mismatches', async () => {
  for (const field of ['resolvedModel', 'usage']) {
    const good = mock(); const bad = { ...good, port: { classify: async (text: string) => ({ ...(await good.port.classify(text)),
      [field]: field === 'resolvedModel' ? 'unapproved-model' : { inputTokens: -1, outputTokens: 30 } }) } };
    const r = await evaluateContextExpansion({ experiment, candidates: [bad] });
    assert.equal(r.stoppedOnOperationalFailure, true); assert.equal(r.results[0].actual, 'unavailable');
    assert.equal(r.results[0].operationalStatus, 'failed');
  }
  for (const decision of ['allow', 'block']) {
    const fixed = { ...mock(), port: { classify: async (text: string) => ({ classification: { policy_version: experiment.policyVersion,
      decision, intent: decision === 'allow' ? 'benign' : 'direct_threat', evidence: [text] }, resolvedModel: 'gpt-6-luna',
      usage: { inputTokens: null, outputTokens: null } }) } };
    const r = await evaluateContextExpansion({ experiment, candidates: [fixed] });
    assert.equal(r.models[0].falseAllows, decision === 'allow' ? 9 : 0);
    assert.equal(r.models[0].falseBlocks, decision === 'block' ? 15 : 0);
    assert.equal(r.models[0].inputTokens, null); assert.equal(r.models[0].usageComplete, false);
    assert.equal(r.allScoredProposalsMatched, false);
  }
  await assert.rejects(evaluateContextExpansion({ experiment, candidates: [mock()], timeoutMs: 0 }));
});

test('v2 request budget stops at 28/56 and on HTTP or transport failure while legacy cap stays separate', async () => {
  for (const limit of [28, 56]) {
    let calls = 0; const budget = createExpansionRequestBudget(limit, async () => { calls++; return Response.json({}); });
    for (let i = 0; i < limit; i++) await budget.fetcher('https://api.openai.com/v1/responses');
    await assert.rejects(budget.fetcher('https://api.openai.com/v1/responses'));
    assert.equal(calls, limit);
  }
  for (const response of [async () => new Response('', { status: 500 }), async () => { throw new Error('private-error'); }]) {
    const budget = createExpansionRequestBudget(56, response);
    try { await budget.fetcher('https://api.openai.com/v1/responses'); } catch {}
    await assert.rejects(budget.fetcher('https://api.openai.com/v1/responses'));
    assert.equal(budget.diagnostics.length, 1); assert.equal(budget.isStopped(), true);
    assert(!JSON.stringify(budget.diagnostics).includes('private-error'));
  }
  assert.throws(() => createExpansionRequestBudget(57));
});
