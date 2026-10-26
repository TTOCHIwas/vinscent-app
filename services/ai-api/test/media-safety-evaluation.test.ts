import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluateMediaSafety, summarizeMediaEvaluation, characterErrorRate } from '../eval/media-safety-evaluation.ts';

const image = { id: 'image-test', kind: 'image' as const, mimeType: 'image/png', bytes: new Uint8Array([1]) };
const audio = { ...image, id: 'audio-test', kind: 'audio' as const, mimeType: 'audio/wav' };
const complete = { status: 'complete', text: '내일 같이 걷자.', language: 'ko', speechDetected: true };
const ports = () => ({
  checkImage: async () => ({ decision: 'allow' }),
  extractText: async () => complete,
  checkText: async () => ({ decision: 'allow' }),
});

test('image evaluation requires both image and extracted Korean text checks', async () => {
  const calls: string[] = [];
  const result = await evaluateMediaSafety(image, {
    checkImage: async () => { calls.push('image'); return { decision: 'allow' }; },
    extractText: async () => { calls.push('ocr'); return complete; },
    checkText: async () => { calls.push('text'); return { decision: 'block' }; },
  });
  assert.equal(result.actual, 'block');
  assert.deepEqual(calls, ['image', 'ocr', 'text']);
});

test('audio evaluation checks the transcript without claiming original sound coverage', async () => {
  const result = await evaluateMediaSafety(audio, ports());
  assert.equal(result.actual, 'allow');
  assert.equal(result.scope, 'transcribed_speech_only');
  assert.equal(result.originalAudioCovered, false);
  assert.equal(JSON.stringify(result).includes(complete.text), false);
});

for (const status of ['failed', 'timeout', 'unsupported', 'partial', 'no_speech', 'unknown']) {
  test(`extraction ${status} is unavailable even if the classifier would allow`, async () => {
    let classified = false;
    const result = await evaluateMediaSafety(audio, { ...ports(),
      extractText: async () => ({ ...complete, status }),
      checkText: async () => { classified = true; return { decision: 'allow' }; },
    });
    assert.equal(result.actual, 'unavailable');
    assert.equal(classified, false);
  });
}

for (const extraction of [null, {}, { ...complete, text: '' }, { ...complete, text: '  ' },
  { ...complete, language: 'en' }, { status: 'no_text', text: 'hidden' }, { status: 'no_text', text: '' }]) {
  test('malformed, empty or non-Korean transcription never approves speech', async () => {
    assert.equal((await evaluateMediaSafety(audio, { ...ports(), extractText: async () => extraction })).actual, 'unavailable');
  });
}

test('a confirmed image without text still requires image classification', async () => {
  assert.equal((await evaluateMediaSafety(image, { ...ports(),
    extractText: async () => ({ status: 'no_text', text: '' }),
  })).actual, 'allow');
  assert.equal((await evaluateMediaSafety(image, { extractText: ports().extractText, checkText: ports().checkText })).actual, 'unavailable');
});

for (const speechDetected of [false, undefined, 'true']) {
  test('a nonempty transcript without positive speech detection cannot approve silence', async () => {
    assert.equal((await evaluateMediaSafety(audio, { ...ports(),
      extractText: async () => ({ ...complete, speechDetected }),
    })).actual, 'unavailable');
  });
}

test('summary rejects invalid and empty evaluation rows', () => {
  assert.throws(() => summarizeMediaEvaluation([]), /invalid_media_evaluation_rows/);
  assert.throws(() => summarizeMediaEvaluation([
    { id: 'invalid', expected: 'allow', actual: 'allow', latencyMs: -1 },
  ]), /invalid_media_evaluation_rows/);
});

for (const decision of [null, {}, { decision: 'safe' }, { decision: true }]) {
  test('malformed image and text decisions cannot approve', async () => {
    assert.equal((await evaluateMediaSafety(image, { ...ports(), checkImage: async () => decision })).actual, 'unavailable');
    assert.equal((await evaluateMediaSafety(audio, { ...ports(), checkText: async () => decision })).actual, 'unavailable');
  });
}

test('provider exceptions are sanitized and are not approvals', async () => {
  for (const stage of ['checkImage', 'extractText', 'checkText']) {
    const result = await evaluateMediaSafety(image, { ...ports(), [stage]: async () => { throw new Error('private upstream body secret'); } });
    assert.equal(result.actual, 'unavailable');
    assert.equal(JSON.stringify(result).includes('private'), false);
  }
});

test('deadline returns unavailable and aborts a provider that ignores cancellation', async () => {
  let signal: AbortSignal | undefined;
  const result = await evaluateMediaSafety(audio, { ...ports(), extractText: async (_part, incoming) => {
    signal = incoming; return new Promise(() => {});
  } }, 5);
  assert.equal(result.actual, 'unavailable');
  assert.equal(result.reason, 'timeout');
  assert.equal(signal?.aborted, true);
});

test('unsupported MIME, empty bytes and malformed media fail before any callback', async () => {
  let calls = 0;
  for (const part of [{ ...image, mimeType: 'image/svg+xml' }, { ...audio, mimeType: 'audio/unknown' },
    { ...image, bytes: new Uint8Array() }, { ...image, kind: 'video' }, { ...image, id: '' }]) {
    assert.equal((await evaluateMediaSafety(part, { extractText: async () => { calls++; return complete; }, checkText: ports().checkText })).actual, 'unavailable');
  }
  assert.equal(calls, 0);
});

test('invalid timeout does not contact providers', async () => {
  for (const timeout of [0, -1, NaN, Infinity, 1.5]) {
    await assert.rejects(evaluateMediaSafety(audio, ports(), timeout), /invalid_media_timeout/);
  }
});

test('incomplete extraction after a visual block remains unavailable', async () => {
  assert.equal((await evaluateMediaSafety(image, { ...ports(), checkImage: async () => ({ decision: 'block' }),
    extractText: async () => ({ status: 'failed' }),
  })).actual, 'unavailable');
});

test('CER preserves Korean negation and normalizes Unicode and spacing', () => {
  assert.equal(characterErrorRate('같이 걷자.', '같이  걷자.'), 0);
  assert.equal(characterErrorRate('가', '\u1100\u1161'), 0);
  assert(characterErrorRate('때리면 안 돼', '때리면 돼') > 0);
  assert.equal(characterErrorRate('', '환각'), 1);
});

test('summary separates classification mistakes, unavailable and extraction quality', () => {
  const report = summarizeMediaEvaluation([
    { id: 'one', expected: 'block', actual: 'allow', latencyMs: 20, referenceText: '안 돼', extractedText: '돼' },
    { id: 'two', expected: 'allow', actual: 'block', latencyMs: 10 },
    { id: 'three', expected: 'unavailable', actual: 'unavailable', latencyMs: 30 },
  ]);
  assert.equal(report.falseAllows, 1);
  assert.equal(report.falseBlocks, 1);
  assert.equal(report.unavailable, 1);
  assert.equal(report.extractionCompared, 1);
  assert.equal(report.latencyP50Ms, 20);
  assert.equal(report.latencyP95Ms, 30);
  assert.equal(JSON.stringify(report).includes('안 돼'), false);
});
