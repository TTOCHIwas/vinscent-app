import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluateContentSafety } from '../src/application/evaluate-content-safety.ts';

const cases = [
  { id: 'normal', group: 'normal', text: '같이 산책하자.', expected: 'allow' as const },
  { id: 'threat', group: 'threat', text: '합성 위협 문장', expected: 'block' as const },
];

test('reports false allows and false blocks separately without echoing Korean content', async () => {
  const report = await evaluateContentSafety({ cases, provider: { supportedKinds: ['text'], check: async (part) => ({
    decision: part.id === 'normal' ? 'block' : 'allow',
  }) } });
  assert.equal(report.falseAllows, 1);
  assert.equal(report.falseBlocks, 1);
  assert.equal(report.unavailable, 0);
  assert.equal(JSON.stringify(report).includes('같이 산책'), false);
});

test('timeouts and invalid outputs are unavailable, not correct blocks', async () => {
  const report = await evaluateContentSafety({ cases, provider: { supportedKinds: ['text'], check: async () => 'safe' } });
  assert.equal(report.unavailable, 2);
  assert.equal(report.correct, 0);
  assert.equal(report.falseAllows, 0);
  assert.equal(report.falseBlocks, 0);
});

test('rejects empty or duplicate evaluation cases before contacting a provider', async () => {
  const provider = { supportedKinds: ['text'] as const, check: async () => { throw new Error('unexpected'); } };
  await assert.rejects(evaluateContentSafety({ cases: [], provider }), /invalid evaluation/);
  await assert.rejects(evaluateContentSafety({ cases: [cases[0], cases[0]], provider }), /invalid evaluation/);
});
