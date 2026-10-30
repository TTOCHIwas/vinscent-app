import assert from 'node:assert/strict';
import test from 'node:test';
import { loadMediaContextInventory, createMediaContextPlan, createMediaContextBudget } from '../eval/media/media-context-plan.ts';
test('media plan binds real 24-case/37-file inventory, v2 policy and per-stage request caps before paid access', () => {
  const inventory = loadMediaContextInventory(); assert.equal(inventory.cases.length, 24); assert.equal(inventory.verifiedFiles, 37);
  const p = createMediaContextPlan('both'); assert.equal(p.limits.maximumRequests, 54);
  assert.equal(p.stageLimits.visualRequests, 10); assert.equal(p.stageLimits.transcriptionRequests, 8);
  assert.equal(p.stageLimits.contextRequestsPerModel, 18);
  assert.equal(p.estimatedUsd, 0.109188); assert.equal(p.conservativeEstimatedUsd, 0.307188);
  assert.equal(createMediaContextPlan('luna').limits.maximumRequests, 36);
  assert.notEqual(p.approvalFingerprint, createMediaContextPlan('terra').approvalFingerprint);
  assert.equal(p.ready, false); assert.equal(p.generalTextSafetyCovered, false);
  assert.throws(() => createMediaContextPlan('unknown'));
});
test('stage budgets reject wrong endpoints and stop after stage quota, HTTP errors or transport errors', async () => {
  let calls = 0; const b = createMediaContextBudget('both', async () => { calls++; return Response.json({}); });
  const init = { body: JSON.stringify({ model: 'gpt-6-luna' }) };
  for (let i = 0; i < 18; i++) await b.fetcher('https://api.openai.com/v1/responses', init);
  await assert.rejects(b.fetcher('https://api.openai.com/v1/responses', init)); assert.equal(calls, 18);
  for (const url of ['https://other.example/v1/responses', 'https://api.openai.com/v1/unknown'])
    await assert.rejects(createMediaContextBudget('both').fetcher(url));
  for (const fail of [async () => new Response('private', { status: 500 }), async () => { throw new Error('private'); }]) {
    const budget = createMediaContextBudget('luna', fail);
    try { await budget.fetcher('https://api.openai.com/v1/responses', init); } catch {}
    assert.equal(budget.isStopped(), true); assert.equal(budget.diagnostics.length, 1);
    await assert.rejects(budget.fetcher('https://api.openai.com/v1/responses', init));
  }
});

test('all stage caps sum to 54 for both; audio and visual quotas cannot be borrowed by context calls', async () => {
  let called = 0; const budget = createMediaContextBudget('both', async () => { called++; return Response.json({}); });
  for (let i = 0; i < 10; i++) await budget.fetcher('https://api.openai.com/v1/moderations', { body: JSON.stringify({ model: 'omni-moderation-latest' }) });
  for (let i = 0; i < 8; i++) { const body = new FormData(); body.set('model', 'gpt-transcribe'); await budget.fetcher('https://api.openai.com/v1/audio/transcriptions', { body }); }
  for (const model of ['gpt-6-luna', 'gpt-6.1-terra']) for (let i = 0; i < 18; i++)
    await budget.fetcher('https://api.openai.com/v1/responses', { body: JSON.stringify({ model }) });
  assert.equal(called, 54); assert.equal(budget.diagnostics.length, 54);
  await assert.rejects(budget.fetcher('https://api.openai.com/v1/moderations', { body: JSON.stringify({ model: 'omni-moderation-latest' }) }));
  assert.equal(called, 54);
});
