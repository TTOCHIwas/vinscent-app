import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequestBudget, mediaEvaluationPlan } from '../eval/media/media-evaluation-plan.ts';

test('approval fingerprint binds provider, ASR and exact fixture manifest', () => {
  const plan = mediaEvaluationPlan('a'.repeat(64), 'openai', 'openai');
  assert.equal(plan.limits.maximumRequests, 34);
  assert.equal(plan.inputs.maximumAudioMinutes, 2);
  assert.notEqual(plan.approvalFingerprint, mediaEvaluationPlan('b'.repeat(64), 'openai', 'openai').approvalFingerprint);
  assert.notEqual(plan.approvalFingerprint, mediaEvaluationPlan('a'.repeat(64), 'cloudflare', 'openai').approvalFingerprint);
  assert.notEqual(plan.approvalFingerprint, mediaEvaluationPlan('a'.repeat(64), 'openai', 'local').approvalFingerprint);
});

test('request cap stops before the next call and never retries', async () => {
  let requests = 0;
  const budget = createRequestBudget(1, async () => { requests++; return Response.json({}); });
  await budget.fetcher('https://example.invalid');
  await assert.rejects(budget.fetcher('https://example.invalid'));
  assert.equal(requests, 1);
});

for (const status of [401, 403, 429, 500]) {
  test(`HTTP ${status} opens the circuit without logging body or key`, async () => {
    let calls = 0;
    const budget = createRequestBudget(34, async () => { calls++; return new Response('secret private response', { status }); });
    await budget.fetcher('https://example.invalid');
    await assert.rejects(budget.fetcher('https://example.invalid'));
    assert.equal(calls, 1);
    assert.equal(JSON.stringify(budget.diagnostics).includes('secret'), false);
    assert.equal(budget.diagnostics[0].status, status);
  });
}
