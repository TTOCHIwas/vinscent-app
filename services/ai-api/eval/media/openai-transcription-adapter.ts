import { requireContentSafetyCredential } from '../../src/infrastructure/content-safety-http.ts';
import { record, type DecodedAudio } from './media-extraction-adapter.ts';

export class OpenAiTranscriptionAdapter {
  readonly #apiKey: string;
  readonly #fetcher: typeof fetch;
  constructor(options: { apiKey: string; fetcher?: typeof fetch }) {
    this.#apiKey = requireContentSafetyCredential(options.apiKey);
    this.#fetcher = options.fetcher ?? fetch;
  }

  async transcribe(audio: DecodedAudio, signal: AbortSignal) {
    try {
      signal.throwIfAborted();
      const body = new FormData();
      body.set('model', 'gpt-transcribe');
      body.set('file', new Blob([Buffer.from(audio.wavBase64, 'base64')], { type: 'audio/wav' }), 'synthetic.wav');
      body.set('languages[]', 'ko');
      const response = await this.#fetcher('https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST', redirect: 'error', signal, headers: { authorization: `Bearer ${this.#apiKey}` }, body,
      });
      if (!response.ok || !response.body) { await response.body?.cancel(); throw new Error(); }
      const reader = response.body.getReader();
      const chunks: Uint8Array[] = [];
      let size = 0;
      try {
        for (;;) {
          const item = await reader.read();
          if (item.done) break;
          size += item.value.length;
          if (size > 65_536) { await reader.cancel(); throw new Error(); }
          chunks.push(item.value);
        }
      } finally { reader.releaseLock(); }
      const data: unknown = JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if (!record(data) || (data.status !== undefined && data.status !== 'completed')
        || typeof data.text !== 'string' || !data.text.trim() || data.text.length > 20_000
        || !Array.isArray(data.languages) || data.languages.length !== 1
        || !record(data.languages[0]) || data.languages[0].code !== 'ko') throw new Error();
      return { text: data.text, language: 'ko' };
    } catch { throw new Error('media_transcription_unavailable'); }
  }
}
