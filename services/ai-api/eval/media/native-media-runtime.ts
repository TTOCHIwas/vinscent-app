import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import type { MediaSample } from '../media-safety-evaluation.ts';
import type { DecodedAudio } from './media-extraction-adapter.ts';
import { record } from './media-extraction-adapter.ts';

export type NativeRunner = (executable: string, args: string[], request: unknown, signal: AbortSignal) => Promise<unknown>;

export class NativeMediaRuntime {
  readonly #options: { python: string; vadModel: string; asrModel: string; run?: NativeRunner };
  constructor(options: { python: string; vadModel: string; asrModel: string; run?: NativeRunner }) { this.#options = options; }

  async #python(operation: string, data: unknown, signal: AbortSignal) {
    try {
      return await (this.#options.run ?? runNative)(this.#options.python,
        [fileURLToPath(new URL('./media_runtime.py', import.meta.url))],
        { operation, data, vadModel: this.#options.vadModel, asrModel: this.#options.asrModel }, signal);
    } catch { throw new Error('media_native_unavailable'); }
  }
  decodeImage(part: MediaSample, signal: AbortSignal) {
    return this.#python('decode_image', { mimeType: part.mimeType, bytes: Buffer.from(part.bytes).toString('base64') }, signal);
  }
  decodeAudio(part: MediaSample, signal: AbortSignal) {
    return this.#python('decode_audio', { mimeType: part.mimeType, bytes: Buffer.from(part.bytes).toString('base64') }, signal);
  }
  detectSpeech(audio: DecodedAudio, signal: AbortSignal) { return this.#python('vad', audio, signal); }
  transcribe(audio: DecodedAudio, signal: AbortSignal) { return this.#python('asr', audio, signal); }
  encodeFixture(data: unknown, signal: AbortSignal) { return this.#python('encode_fixture', data, signal); }
  async ocr(image: unknown, signal: AbortSignal) {
    try {
      if (!record(image) || typeof image.pngBase64 !== 'string') throw new Error();
      const execute = (pngBase64: string) => (this.#options.run ?? runNative)('powershell.exe',
        ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', fileURLToPath(new URL('./windows-media.ps1', import.meta.url))],
        { operation: 'ocr', pngBase64 }, signal);
      const original = await execute(image.pngBase64);
      if (record(original) && original.words === 0 && original.text === '' && typeof image.ocrPngBase64 === 'string') {
        return await execute(image.ocrPngBase64);
      }
      return original;
    } catch { throw new Error('media_native_unavailable'); }
  }
  synthesize(text: string, signal: AbortSignal) {
    return (this.#options.run ?? runNative)('powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', fileURLToPath(new URL('./windows-media.ps1', import.meta.url))],
      { operation: 'synthesize', text }, signal);
  }
}

export const runNative: NativeRunner = async (executable, args, request, signal) => {
  signal.throwIfAborted();
  return new Promise((resolve, reject) => {
    const env = Object.fromEntries(Object.entries(process.env).filter(([key]) =>
      /^(PATH|SYSTEMROOT|WINDIR|TEMP|TMP|HOME|USERPROFILE|LANG|LC_ALL)$/i.test(key)));
    env.PYTHONIOENCODING = 'utf-8';
    const child = spawn(executable, args, { shell: false, windowsHide: true, env, stdio: ['pipe', 'pipe', 'pipe'] });
    const chunks: Buffer[] = [];
    let size = 0;
    let ended = false;
    const timer = setTimeout(() => finish(new Error()), 20_000);
    const abort = () => finish(new Error());
    const finish = (error?: Error, value?: unknown) => {
      if (ended) return;
      ended = true; clearTimeout(timer); signal.removeEventListener('abort', abort);
      if (error) { child.kill(); reject(new Error('media_native_unavailable')); } else resolve(value);
    };
    signal.addEventListener('abort', abort, { once: true });
    if (signal.aborted) abort();
    child.on('error', () => finish(new Error()));
    child.stdin.on('error', () => finish(new Error()));
    child.stderr.on('data', () => {});
    child.stdout.on('data', (chunk: Buffer) => {
      size += chunk.length;
      if (size > 30 * 1024 * 1024) finish(new Error()); else chunks.push(chunk);
    });
    child.on('close', code => {
      if (code !== 0) return finish(new Error());
      try { finish(undefined, JSON.parse(Buffer.concat(chunks).toString('utf8').replace(/^\uFEFF/, ''))); }
      catch { finish(new Error()); }
    });
    child.stdin.end(JSON.stringify(request));
  });
};
