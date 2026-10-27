import type { MediaSample } from '../media-safety-evaluation.ts';

export type DecodedAudio = { wavBase64: string; durationMs: number; sampleRate: number; samples: number };
export interface MediaExtractionDependencies {
  decodeImage(part: MediaSample, signal: AbortSignal): Promise<unknown>;
  decodeAudio(part: MediaSample, signal: AbortSignal): Promise<unknown>;
  ocr(image: unknown, signal: AbortSignal): Promise<unknown>;
  detectSpeech(audio: DecodedAudio, signal: AbortSignal): Promise<unknown>;
  transcribe(audio: DecodedAudio, signal: AbortSignal): Promise<unknown>;
}
export const record = (v: unknown): v is Record<string, unknown> => v !== null && typeof v === 'object' && !Array.isArray(v);

/** Evaluation-only extraction. No reference script is accepted by this adapter. */
export class MediaExtractionAdapter {
  readonly #ports: MediaExtractionDependencies;
  constructor(ports: MediaExtractionDependencies) { this.#ports = ports; }

  async extract(part: MediaSample, signal: AbortSignal) {
    try {
      signal.throwIfAborted();
      if (part.kind === 'image') {
        const image = await this.#ports.decodeImage(part, signal);
        signal.throwIfAborted();
        const ocr = await this.#ports.ocr(image, signal);
        signal.throwIfAborted();
        if (!record(ocr) || typeof ocr.text !== 'string' || !Number.isSafeInteger(ocr.words)
          || Number(ocr.words) < 0 || ocr.text.length > 20_000) throw new Error();
        if (ocr.words === 0 && ocr.text === '') return { status: 'no_text', text: '', language: 'ko' };
        if (!ocr.text.trim() || Number(ocr.words) === 0) throw new Error();
        return { status: 'complete', text: ocr.text, language: 'ko' };
      }
      if (part.kind !== 'audio') return { status: 'unsupported' };
      const decoded = await this.#ports.decodeAudio(part, signal);
      signal.throwIfAborted();
      if (!record(decoded) || typeof decoded.wavBase64 !== 'string' || !decoded.wavBase64
        || !Number.isFinite(decoded.durationMs) || Number(decoded.durationMs) <= 0
        || Number(decoded.durationMs) > 15_000 || decoded.sampleRate !== 16000
        || !Number.isSafeInteger(decoded.samples) || Number(decoded.samples) < 1) throw new Error();
      const audio = decoded as DecodedAudio;
      const vad = await this.#ports.detectSpeech(audio, signal);
      signal.throwIfAborted();
      if (!record(vad) || vad.speechDetected !== true || typeof vad.speechMs !== 'number'
        || !Number.isFinite(vad.speechMs)
        || vad.speechMs < 250 || vad.speechMs > audio.durationMs + 32
        || typeof vad.maximumProbability !== 'number' || !Number.isFinite(vad.maximumProbability) || vad.maximumProbability < 0.5
        || vad.maximumProbability > 1) return { status: 'no_speech', speechDetected: false };
      const transcript = await this.#ports.transcribe(audio, signal);
      signal.throwIfAborted();
      if (!record(transcript) || typeof transcript.text !== 'string' || !transcript.text.trim()
        || transcript.text.length > 20_000 || transcript.language !== 'ko'
        || (transcript.confidence !== undefined && (typeof transcript.confidence !== 'number'
          || !Number.isFinite(transcript.confidence) || transcript.confidence < 0.8 || transcript.confidence > 1))) {
        return { status: 'partial', speechDetected: true };
      }
      return { status: 'complete', text: transcript.text, language: 'ko', speechDetected: true };
    } catch { return { status: signal.aborted ? 'timeout' : 'failed' }; }
  }
}
