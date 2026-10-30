import assert from 'node:assert/strict';
import test from 'node:test';
import { MediaExtractionAdapter } from '../eval/media/media-extraction-adapter.ts';
import { OpenAiTranscriptionAdapter } from '../eval/media/openai-transcription-adapter.ts';
import { NativeMediaRuntime } from '../eval/media/native-media-runtime.ts';

const signal = () => new AbortController().signal;
const image = { id: 'test-image', kind: 'image' as const, mimeType: 'image/jpeg', bytes: new Uint8Array([1]) };
const audio = { ...image, id: 'test-audio', kind: 'audio' as const, mimeType: 'audio/mp4' };
const decodedAudio = { wavBase64: 'UklGRg==', durationMs: 2500, sampleRate: 16000, samples: 40000 };
const dependencies = () => ({
  decodeImage: async () => ({ pngBase64: 'iVBORw==', width: 640, height: 480 }),
  decodeAudio: async () => decodedAudio,
  ocr: async () => ({ text: '내일 같이 걷자.', words: 3 }),
  detectSpeech: async () => ({ speechDetected: true, speechMs: 1000, maximumProbability: 0.9 }),
  transcribe: async () => ({ text: '내일 같이 걷자.', language: 'ko', confidence: 0.95 }),
});

test('explicit partial OCR and ASR status cannot be upgraded to complete extraction', async () => {
  for (const status of ['partial', 'failed', 'timeout', ['complete']]) {
    const ocr = new MediaExtractionAdapter({ ...dependencies(), ocr: async () => ({ text: '일부만 인식', words: 2, status }) });
    const asr = new MediaExtractionAdapter({ ...dependencies(), transcribe: async () => ({ text: '일부만 인식', language: 'ko', status }) });
    assert.notEqual((await ocr.extract(image, signal())).status, 'complete');
    assert.notEqual((await asr.extract(audio, signal())).status, 'complete');
  }
});

test('media extraction uses decoded bytes, actual OCR and ASR, without a reference script', async () => {
  const used: string[] = [];
  const adapter = new MediaExtractionAdapter({ ...dependencies(), transcribe: async (wav) => {
    used.push(wav.wavBase64); return { text: '실제로 인식한 문장', language: 'ko', confidence: 0.91 };
  } });
  assert.equal((await adapter.extract(audio, signal())).text, '실제로 인식한 문장');
  assert.deepEqual(used, [decodedAudio.wavBase64]);
  assert.equal((await adapter.extract(image, signal())).text, '내일 같이 걷자.');
});

for (const vad of [null, {}, { speechDetected: false, speechMs: 0, maximumProbability: 0.01 },
  { speechDetected: true, speechMs: 0, maximumProbability: 0.1 },
  { speechDetected: true, speechMs: NaN, maximumProbability: NaN }]) {
  test('silence and missing VAD evidence never reach paid transcription', async () => {
    let calls = 0;
    const adapter = new MediaExtractionAdapter({ ...dependencies(), detectSpeech: async () => vad,
      transcribe: async () => { calls++; return { text: '환각', language: 'ko' }; } });
    assert.notEqual((await adapter.extract(audio, signal())).status, 'complete');
    assert.equal(calls, 0);
  });
}

for (const transcript of [null, {}, { text: '', language: 'ko' }, { text: 'hello', language: 'en' },
  { text: '불확실', language: 'ko', confidence: 0.2 }]) {
  test('missing, foreign or unreliable recognition stays unavailable', async () => {
    const adapter = new MediaExtractionAdapter({ ...dependencies(), transcribe: async () => transcript });
    assert.notEqual((await adapter.extract(audio, signal())).status, 'complete');
  });
}

for (const method of ['decodeImage', 'decodeAudio', 'ocr', 'detectSpeech', 'transcribe']) {
  test(`${method} failure is sanitized and never approves`, async () => {
    const adapter = new MediaExtractionAdapter({ ...dependencies(), [method]: async () => { throw new Error('secret private upstream'); } });
    const result = await adapter.extract(['decodeImage', 'ocr'].includes(method) ? image : audio, signal());
    assert.notEqual(result.status, 'complete');
    assert.equal(JSON.stringify(result).includes('secret'), false);
  });
}

test('a pre-aborted extraction contacts no decoder', async () => {
  const controller = new AbortController(); controller.abort();
  let called = false;
  const adapter = new MediaExtractionAdapter({ ...dependencies(), decodeAudio: async () => { called = true; return decodedAudio; } });
  assert.notEqual((await adapter.extract(audio, controller.signal)).status, 'complete');
  assert.equal(called, false);
});

test('OpenAI transcription sends the normalized file without expected text or prompts', async () => {
  const adapter = new OpenAiTranscriptionAdapter({ apiKey: 'test-only', fetcher: async (url, init) => {
    assert.equal(url, 'https://api.openai.com/v1/audio/transcriptions');
    assert.equal(init?.redirect, 'error');
    const form = init?.body as FormData;
    assert.equal(form.get('model'), 'gpt-transcribe');
    assert.equal(form.get('prompt'), null);
    assert.equal(form.get('keywords[]'), null);
    assert(form.get('file') instanceof Blob);
    return Response.json({ text: '관측 문장', languages: [{ code: 'ko' }] });
  } });
  assert.equal((await adapter.transcribe(decodedAudio, signal())).text, '관측 문장');
});

test('explicit incomplete ASR API response is rejected before it can lose its status', async () => {
  for (const status of ['partial', 'failed', 'incomplete', ['completed']]) {
    const adapter = new OpenAiTranscriptionAdapter({ apiKey: 'unit-test-only', fetcher: async () =>
      Response.json({ status, text: '일부만 인식된 실제 응답', languages: [{ code: 'ko' }] }) });
    await assert.rejects(adapter.transcribe(decodedAudio, signal()), /media_transcription_unavailable/);
  }
});

for (const body of [{}, { text: '', languages: [{ code: 'ko' }] }, { text: '환각', languages: [] },
  { text: 'hello', languages: [{ code: 'en' }] }, { text: 'mixed', languages: [{ code: 'ko' }, { code: 'en' }] }]) {
  test('invalid ASR responses cannot become complete Korean speech', async () => {
    const adapter = new OpenAiTranscriptionAdapter({ apiKey: 'test', fetcher: async () => Response.json(body) });
    await assert.rejects(adapter.transcribe(decodedAudio, signal()), /media_transcription_unavailable/);
  });
}

for (const status of [401, 403, 429, 500]) {
  test(`ASR ${status} response is not leaked or retried`, async () => {
    let calls = 0;
    const adapter = new OpenAiTranscriptionAdapter({ apiKey: 'secret', fetcher: async () => {
      calls++; return new Response('private secret', { status });
    } });
    await assert.rejects(adapter.transcribe(decodedAudio, signal()), { message: 'media_transcription_unavailable' });
    assert.equal(calls, 1);
  });
}

test('native runner errors and invalid JSON are sanitized', async () => {
  const runtime = new NativeMediaRuntime({ python: 'python', vadModel: 'model', asrModel: 'asr',
    run: async () => { throw new Error('private absolute path token'); } });
  await assert.rejects(runtime.decodeAudio(audio, signal()), { message: 'media_native_unavailable' });
});

test('OCR preserves the original and uses enhancement only when original extraction has no text', async () => {
  const used: string[] = [];
  const runtime = new NativeMediaRuntime({ python: 'unused', vadModel: '', asrModel: '', run: async (_exe, _args, request: any) => {
    used.push(request.pngBase64);
    return { text: '회색 배경의 실제 글', words: 4 };
  } });
  assert.equal((await runtime.ocr({ pngBase64: 'original', ocrPngBase64: 'enhanced' }, signal()) as any).text, '회색 배경의 실제 글');
  assert.deepEqual(used, ['original']);
});
