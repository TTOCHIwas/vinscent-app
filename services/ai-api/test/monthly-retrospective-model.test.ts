import assert from 'node:assert/strict';
import test from 'node:test';
import { MonthlyRetrospectiveModel } from '../src/application/monthly-retrospective-model.ts';

const context = {
  month: '2026-09-01',
  questions: [{ id: 'q1', text: '다시 하고 싶은 일은?', answers: ['같이 커피 마시기', '산책하고 커피 마시기'] }],
};
const candidate = {
  title: '커피와 산책을 나눈 9월',
  summary_sentences: ['함께 커피를 마시는 시간을 다시 보내고 싶다고 남겼어.', '산책도 다시 하고 싶은 일로 적었어.'],
  question: '다음 달 함께 다시 하고 싶은 일은 뭐야?',
  evidence_question_ids: ['q1'],
};

test('generates a grounded monthly result using only anonymized answers', async () => {
  let prompt = '';
  const model = new MonthlyRetrospectiveModel({ generateStructured: async (request) => {
    prompt = request.prompt;
    return { value: candidate, usage: { inputTokenCount: 1, outputTokenCount: 1, latencyMs: 1 } };
  } });
  assert.deepEqual(await model.generate(context), candidate);
  assert.match(prompt, /2026-09-01/);
  assert.match(prompt, /같이 커피/);
});

test('rejects a fabricated evidence reference', async () => {
  const model = new MonthlyRetrospectiveModel({ generateStructured: async () => ({
    value: { ...candidate, evidence_question_ids: ['unknown'] },
    usage: { inputTokenCount: 1, outputTokenCount: 1, latencyMs: 1 },
  }) });
  await assert.rejects(model.generate(context), /evidence/);
});

test('rejects summaries outside the required sentence count', async () => {
  const model = new MonthlyRetrospectiveModel({ generateStructured: async () => ({
    value: { ...candidate, summary_sentences: ['한 문장'] },
    usage: { inputTokenCount: 1, outputTokenCount: 1, latencyMs: 1 },
  }) });
  await assert.rejects(model.generate(context), /summary/);
});

test('does not call the model without shared answers', async () => {
  const model = new MonthlyRetrospectiveModel({ generateStructured: async () => { throw new Error('unexpected call'); } });
  await assert.rejects(model.generate({ ...context, questions: [] }), /evidence/);
});
