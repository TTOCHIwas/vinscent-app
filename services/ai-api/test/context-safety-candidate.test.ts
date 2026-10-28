import assert from 'node:assert/strict';
import test from 'node:test';
import { createHash } from 'node:crypto';
import { createContextEvaluationPlan } from '../eval/context/context-evaluation-plan.ts';
import { OpenAiContextSafetyCandidate } from '../eval/context/openai-context-safety-candidate.ts';
import { contextPolicyVersion, contextInstructions, parseContextClassification } from '../eval/context/context-policy.ts';

const text = '때리거나 협박하면 안 돼.';
const classification = () => ({ policy_version: contextPolicyVersion, decision: 'allow', intent: 'harm_prevention', evidence: [text] });
const envelope = (value: unknown = classification()) => ({ status: 'completed', model: 'gpt-6-luna', usage: { input_tokens: 100, output_tokens: 30 },
  output: [{ type: 'message', role: 'assistant', status: 'completed', content: [{ type: 'output_text', text: JSON.stringify(value) }] }] });
const signal = () => new AbortController().signal;

test('context candidate sends only actual text and generic policy, without fixture labels or example answers', async () => {
  const candidate = new OpenAiContextSafetyCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', fetcher: async (url, init) => {
    assert.equal(url, 'https://api.openai.com/v1/responses');
    assert.equal(init?.redirect, 'error');
    const body = JSON.parse(init!.body as string);
    assert.equal(body.instructions, contextInstructions);
    assert.deepEqual(JSON.parse(body.input[0].content[0].text), { text });
    assert.equal(body.store, false);
    assert.equal(body.service_tier, 'default');
    assert.deepEqual(body.reasoning, { effort: 'none' });
    assert.deepEqual(body.tools, []);
    assert.equal(body.max_output_tokens, 512);
    assert.equal(body.text.format.strict, true);
    assert.equal(JSON.stringify(body).includes('violence-prevention'), false);
    assert.equal(JSON.stringify(body).includes('expected'), false);
    const actualConfiguration = { ...body };
    delete actualConfiguration.model; delete actualConfiguration.instructions; delete actualConfiguration.input;
    assert.equal(createContextEvaluationPlan('luna').requestConfigurationSha256,
      createHash('sha256').update(JSON.stringify(actualConfiguration)).digest('hex'));
    return Response.json(envelope());
  } });
  const result = await candidate.classify(text, signal());
  assert.deepEqual(result.classification, classification());
  assert.equal(result.resolvedModel, 'gpt-6-luna');
  assert.deepEqual(result.usage, { inputTokens: 100, outputTokens: 30 });
});

for (const value of [
  { ...classification(), decision: 'allow', intent: 'coercion' },
  { ...classification(), decision: ['allow'] },
  { ...classification(), evidence: ['입력에 없는 근거'] },
  { ...classification(), evidence: [] },
  { ...classification(), policy_version: 'stale' },
  { ...classification(), extra: 'synthetic-private-output' }, null,
]) {
  test('malformed, contradictory or ungrounded classifications never become allow', () => {
    assert.throws(() => parseContextClassification(value, text), /context_candidate_unavailable/);
  });
}

for (const status of ['incomplete', 'failed', 'cancelled']) {
  test(`${status} response is unavailable and never retried`, async () => {
    let calls = 0;
    const candidate = new OpenAiContextSafetyCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', fetcher: async () => {
      calls++; return Response.json({ ...envelope(), status });
    } });
    await assert.rejects(candidate.classify(text, signal()), { message: 'context_candidate_unavailable' });
    assert.equal(calls, 1);
  });
}

test('refusal, tool output and duplicate assistant messages are not classifier answers', async () => {
  for (const output of [
    [{ type: 'message', role: 'assistant', status: 'completed', content: [{ type: 'refusal', refusal: 'synthetic-private-refusal' }] }],
    [{ type: 'function_call', name: 'fake' }], [...envelope().output, ...envelope().output],
    [...envelope().output, { type: ['reasoning'] }],
  ]) {
    const candidate = new OpenAiContextSafetyCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', fetcher: async () => Response.json({ ...envelope(), output }) });
    await assert.rejects(candidate.classify(text, signal()), { message: 'context_candidate_unavailable' });
  }
});

for (const status of [401, 403, 429, 500]) {
  test(`context HTTP ${status} never exposes upstream text or retries`, async () => {
    let calls = 0;
    const candidate = new OpenAiContextSafetyCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', fetcher: async () => {
      calls++; return new Response('synthetic-private-error', { status });
    } });
    await assert.rejects(candidate.classify(text, signal()), { message: 'context_candidate_unavailable' });
    assert.equal(calls, 1);
  });
}

test('missing or malformed token usage cannot be reported as measured zero', async () => {
  const absent = new OpenAiContextSafetyCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', fetcher: async () => {
    const body: any = envelope(); delete body.usage; return Response.json(body);
  } });
  assert.deepEqual((await absent.classify(text, signal())).usage, { inputTokens: null, outputTokens: null });
  const malformed = new OpenAiContextSafetyCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', fetcher: async () =>
    Response.json({ ...envelope(), usage: { input_tokens: -1, output_tokens: 30 } }) });
  await assert.rejects(malformed.classify(text, signal()), /context_candidate_unavailable/);
});

test('invalid, non-text, oversized or pre-aborted requests contact no API', async () => {
  let calls = 0;
  const candidate = new OpenAiContextSafetyCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', fetcher: async () => { calls++; return Response.json(envelope()); } });
  for (const input of ['', { kind: 'image', bytes: [1] }, '가'.repeat(401)]) {
    await assert.rejects(candidate.classify(input as string, signal()), /context_candidate_unavailable/);
  }
  const controller = new AbortController(); controller.abort();
  await assert.rejects(candidate.classify(text, controller.signal), /context_candidate_unavailable/);
  assert.equal(calls, 0);
});
