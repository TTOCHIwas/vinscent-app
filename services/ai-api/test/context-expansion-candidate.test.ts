import assert from 'node:assert/strict';
import test from 'node:test';
import { createHash } from 'node:crypto';
import { createContextExpansionExperiment, parseExpansionClassification } from '../eval/context/context-expansion-experiment.ts';
import { OpenAiContextExpansionCandidate } from '../eval/context/openai-context-expansion-candidate.ts';
import { createExpansionEvaluationPlan } from '../eval/context/context-expansion-plan.ts';

const experiment = createContextExpansionExperiment();
const text = experiment.cases.find(c => c.group === 'report_and_quotation')!.text;
const value = () => ({ policy_version: experiment.policyVersion, decision: 'allow', intent: 'victim_report', evidence: [text] });
const envelope = () => ({ status: 'completed', model: 'gpt-6-luna', usage: { input_tokens: 100, output_tokens: 40 },
  output: [{ type: 'message', role: 'assistant', status: 'completed', content: [{ type: 'output_text', text: JSON.stringify(value()) }] }] });

test('v2 sends real text only and generic policy, binding actual request configuration to approval plan', async () => {
  let calls = 0;
  const candidate = new OpenAiContextExpansionCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', experiment,
    fetcher: async (url, init) => {
      calls++; assert.equal(url, 'https://api.openai.com/v1/responses');
      const body = JSON.parse(init!.body as string);
      assert.equal(body.instructions, experiment.instructions);
      assert.deepEqual(JSON.parse(body.input[0].content[0].text), { text });
      assert.equal(body.store, false); assert.equal(body.max_output_tokens, 512);
      assert.equal(body.text.format.schema.properties.policy_version.enum[0], experiment.policyVersion);
      const config = { ...body }; delete config.model; delete config.instructions; delete config.input;
      assert.equal(createExpansionEvaluationPlan('luna', experiment).requestConfigurationSha256,
        createHash('sha256').update(JSON.stringify(config)).digest('hex'));
      assert(!JSON.stringify(body).includes('proposedDecision'));
      for (const c of experiment.cases) assert(!body.instructions.includes(c.text));
      return Response.json(envelope());
    } });
  assert.deepEqual((await candidate.classify(text, new AbortController().signal)).classification, value());
  assert.equal(calls, 1);
  assert.throws(() => { (experiment.cases[0] as any).text = 'changed'; });
});

for (const [intent, decision] of [['coercion', 'block'], ['direct_threat', 'block'], ['harm_prevention', 'allow'],
  ['benign', 'allow'], ['victim_report', 'allow'], ['fictional_quote', 'allow'], ['unresolved_context', 'unavailable']]) {
  test(`v2 validates ${intent} without substituting an expected label`, () => {
    const result = parseExpansionClassification({ ...value(), intent, decision }, text);
    assert.equal(result.intent, intent); assert.equal(result.decision, decision);
  });
}

for (const mutate of [
  (v: any) => { v.policy_version = 'ko-context-candidate-v1'; },
  (v: any) => { v.decision = 'allow'; v.intent = 'coercion'; },
  (v: any) => { v.intent = ['victim_report']; },
  (v: any) => { v.evidence = ['not-in-input']; },
  (v: any) => { v.evidence = []; },
  (v: any) => { v.extra = true; },
]) test('v2 rejects wrong policy, contradictory decisions, coercion and ungrounded evidence', () => {
  const v = value(); mutate(v); assert.throws(() => parseExpansionClassification(v, text));
});

test('v2 failures, refusals and malformed envelopes stay unavailable without retry or upstream output', async () => {
  for (const response of [() => new Response('synthetic-private-error', { status: 401 }),
    () => new Response('synthetic-private-error', { status: 429 }),
    () => Response.json({ ...envelope(), status: 'incomplete' }),
    () => Response.json({ ...envelope(), output: [{ type: 'function_call' }] }),
    () => Response.json({ ...envelope(), output: [...envelope().output, ...envelope().output] }),
    () => Response.json({ ...envelope(), output: [{ type: 'message', role: 'assistant', status: 'completed', content: [{ type: 'refusal' }] }] }),
    () => { throw new Error('synthetic-private-transport'); }]) {
    let calls = 0;
    const c = new OpenAiContextExpansionCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', experiment,
      fetcher: async () => { calls++; return response(); } });
    await assert.rejects(c.classify(text, new AbortController().signal), { message: 'context_candidate_unavailable' });
    assert.equal(calls, 1);
  }
});

test('v2 rejects nontext, oversized and pre-aborted inputs before API; absent usage remains unknown', async () => {
  let calls = 0;
  const c = new OpenAiContextExpansionCandidate({ apiKey: 'unit-test-only', model: 'gpt-6-luna', experiment,
    fetcher: async () => { calls++; const v: any = envelope(); delete v.usage; return Response.json(v); } });
  for (const input of ['', '가'.repeat(401), { kind: 'image' }]) await assert.rejects(c.classify(input as string, new AbortController().signal));
  const a = new AbortController(); a.abort(); await assert.rejects(c.classify(text, a.signal)); assert.equal(calls, 0);
  assert.deepEqual((await c.classify(text, new AbortController().signal)).usage, { inputTokens: null, outputTokens: null });
});
