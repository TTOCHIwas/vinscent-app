import assert from 'node:assert/strict';
import test from 'node:test';
import { runNative, NativeMediaRuntime } from '../eval/media/native-media-runtime.ts';

test('native JSON process receives input but no inherited provider credentials', async () => {
  process.env.CONTENT_SAFETY_TEST_SECRET = 'synthetic-test-value';
  try {
    const result = await runNative(process.execPath, ['-e', `
      let input = ''; process.stdin.on('data', chunk => input += chunk);
      process.stdin.on('end', () => console.log(JSON.stringify({
        operation: JSON.parse(input).operation,
        leaked: Object.keys(process.env).some(key => key.startsWith('CONTENT_SAFETY_'))
      })));
    `], { operation: 'test' }, AbortSignal.timeout(5000));
    assert.deepEqual(result, { operation: 'test', leaked: false });
  } finally { delete process.env.CONTENT_SAFETY_TEST_SECRET; }
});

for (const code of ["console.error('synthetic-private-error'); process.exit(1)", "console.log('invalid-json')"]) {
  test('invalid native output and process errors expose only a fixed error', async () => {
    await assert.rejects(runNative(process.execPath, ['-e', code], {}, AbortSignal.timeout(5000)),
      { message: 'media_native_unavailable' });
  });
}

test('cancellation terminates a running native operation', async () => {
  const controller = new AbortController();
  const result = runNative(process.execPath, ['-e', 'process.stdin.resume(); setInterval(() => {}, 1000)'], {}, controller.signal);
  const timer = setTimeout(() => controller.abort(), 100);
  try { await assert.rejects(result, { message: 'media_native_unavailable' }); }
  finally { clearTimeout(timer); }
});

test('missing native executable fails without leaking its path', async () => {
  await assert.rejects(runNative('missing-synthetic-media-executable', [], {}, AbortSignal.timeout(5000)),
    { message: 'media_native_unavailable' });
});

test('OCR fallback uses enhanced pixels only after actual empty OCR', async () => {
  const used: string[] = [];
  const runtime = new NativeMediaRuntime({ python: '', vadModel: '', asrModel: '',
    run: async (_exe, _args, request: unknown) => {
      const input = request as { pngBase64: string }; used.push(input.pngBase64);
      return used.length === 1 ? { text: '', words: 0 } : { text: '관측 글', words: 2 };
    } });
  assert.deepEqual(await runtime.ocr({ pngBase64: 'original', ocrPngBase64: 'enhanced' }, AbortSignal.timeout(5000)),
    { text: '관측 글', words: 2 });
  assert.deepEqual(used, ['original', 'enhanced']);
});
