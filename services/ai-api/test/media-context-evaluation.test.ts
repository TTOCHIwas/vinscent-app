import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluateMediaContext, evaluateMediaContextBatch } from '../eval/media/media-context-evaluation.ts';
const image = { id: 'image-observed', kind: 'image' as const, mimeType: 'image/jpeg', bytes: new Uint8Array([1]) };
const audio = { ...image, id: 'audio-observed', kind: 'audio' as const, mimeType: 'audio/mp4' };
const text = '실제로 추출한 문장';
const extraction = () => ({ status: 'complete', text, language: 'ko', speechDetected: true });
const observation = (model = 'gpt-6-luna', decision = 'allow', intent = 'benign') => ({
  classification: { policy_version: 'ko-context-proposal-v2', decision, intent, evidence: [text] },
  resolvedModel: model, usage: { inputTokens: 100, outputTokens: 30 },
});
const ports = () => ({ model: 'gpt-6-luna', extractText: async () => extraction(), checkImage: async () => ({ decision: 'allow' }),
  classifyText: async (actual: string) => { assert.equal(actual, text); return observation(); } });

test('media context forwards actual OCR/ASR text, stores only hashes, and never claims general or original-audio coverage', async () => {
  for (const sample of [image, audio]) {
    const result = await evaluateMediaContext(sample, ports());
    assert.equal(result.actual, 'allow'); assert.equal(result.contextDecision, 'allow');
    assert.match(result.observedTextSha256!, /^[a-f0-9]{64}$/);
    assert.equal(result.generalTextSafetyCovered, false); assert.equal(result.originalAudioCovered, false);
    assert(!JSON.stringify(result).includes(text));
  }
});
test('context allow cannot override visual block; context unavailable cannot approve a visual allow', async () => {
  assert.equal((await evaluateMediaContext(image, { ...ports(), checkImage: async () => ({ decision: 'block' }) })).actual, 'block');
  const unavailable = await evaluateMediaContext(image, { ...ports(), classifyText: async () => observation('gpt-6-luna', 'unavailable', 'unresolved_context') });
  assert.equal(unavailable.actual, 'unavailable'); assert.equal(unavailable.reason, 'context_unresolved');
  assert.equal(unavailable.operationalFailure, false);
});
for (const status of ['partial', 'failed', 'timeout', 'unsupported', 'no_speech', 'unknown', 'no_text'])
  test(`extraction ${status} cannot approve or reach context classification`, async () => {
    let calls = 0;
    const result = await evaluateMediaContext(image, { ...ports(), extractText: async () => ({ ...extraction(), status, text: status === 'no_text' ? '' : text }),
      classifyText: async () => { calls++; return observation(); } });
    assert.equal(result.actual, 'unavailable'); assert.equal(calls, 0);
  });
test('invalid model, evidence, usage and timeout remain unavailable without private output', async () => {
  for (const value of [{ ...observation(), resolvedModel: 'other' }, { ...observation(), usage: { inputTokens: -1, outputTokens: 3 } },
    { ...observation(), classification: { ...observation().classification, evidence: ['not-observed'] } }, null]) {
    const r = await evaluateMediaContext(audio, { ...ports(), classifyText: async () => value });
    assert.equal(r.actual, 'unavailable'); assert.equal(r.operationalFailure, true);
  }
  const timed = await evaluateMediaContext(audio, { ...ports(), classifyText: async () => new Promise(() => {}) }, 5);
  assert.equal(timed.actual, 'unavailable'); assert.equal(timed.reason, 'timeout');
  const bad = await evaluateMediaContext(audio, { ...ports(), extractText: async () => { throw new Error('private-secret'); } });
  assert.equal(bad.actual, 'unavailable'); assert(!JSON.stringify(bad).includes('private-secret'));
});
test('image without visual checker and coercible MIME cannot approve', async () => {
  const p = ports(); const { checkImage, ...withoutVisual } = p;
  assert.equal((await evaluateMediaContext(image, withoutVisual)).actual, 'unavailable');
  assert.equal((await evaluateMediaContext({ ...image, mimeType: ['image/jpeg'] }, p)).actual, 'unavailable');
});
const rows = () => [{ part: audio, sourceSha256: 'a'.repeat(64), expected: 'block' as const, referenceText: '정답 대본을 보내면 안 됨', externalEligible: true }];
const candidates = () => ['luna', 'terra'].map(id => ({ id, model: id === 'luna' ? 'gpt-6-luna' : 'gpt-6.1-terra',
  port: { classify: async (actual: string) => { assert.equal(actual, text); return observation(id === 'luna' ? 'gpt-6-luna' : 'gpt-6.1-terra'); } } }));
test('batch shares one real extraction and visual observation across both candidates; labels never supply recognition', async () => {
  let extracted = 0; let visual = 0;
  const input = [{ ...rows()[0], part: image }];
  const r = await evaluateMediaContextBatch(input, { extractText: async (part: any) => {
    extracted++; assert.equal(part.referenceText, undefined); return extraction();
  }, checkImage: async () => { visual++; return { decision: 'allow' }; }, candidates: candidates() });
  assert.equal(extracted, 1); assert.equal(visual, 1); assert.equal(r.results.length, 2);
  assert(!JSON.stringify(r).includes(text)); assert.equal(r.ready, false);
});
test('negative controls never reach external checks even if extraction unexpectedly returns text', async () => {
  let called = 0;
  const r = await evaluateMediaContextBatch([{ ...rows()[0], externalEligible: false }], {
    extractText: async () => extraction(), checkImage: async () => { called++; return { decision: 'allow' }; },
    candidates: candidates().map(c => ({ ...c, port: { classify: async () => { called++; return observation(c.model); } } })) });
  assert.equal(called, 0); assert(r.results.every(x => x.actual === 'unavailable'));
});
test('operational failure stops both candidates and all remaining cases', async () => {
  let called = 0;
  const cs = candidates(); cs[0].port.classify = async () => { called++; throw new Error('private'); };
  const r = await evaluateMediaContextBatch(rows(), { extractText: async () => extraction(), checkImage: ports().checkImage, candidates: cs });
  assert.equal(called, 1); assert.equal(r.stoppedOnOperationalFailure, true); assert.equal(r.results.length, 1);
});
