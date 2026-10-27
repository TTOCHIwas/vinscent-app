import { contentSafetyDecisionFrom } from '../src/domain/content-safety.ts';

export type MediaSample = {
  id: string; kind: 'image' | 'audio'; mimeType: string; bytes: Uint8Array;
};
export interface MediaEvaluationPorts {
  checkImage?(part: MediaSample, signal: AbortSignal): Promise<unknown>;
  extractText(part: MediaSample, signal: AbortSignal): Promise<unknown>;
  checkText(text: string, signal: AbortSignal): Promise<unknown>;
}
type Decision = 'allow' | 'block' | 'unavailable';
type Reason = 'completed' | 'unsupported_or_invalid' | 'extraction_incomplete' | 'provider_failure' | 'timeout';

/** Evaluation-only composition; this is not a publication approval or an ASR quality detector. */
export async function evaluateMediaSafety(
  sample: unknown, ports: MediaEvaluationPorts, timeoutMs = 15_000,
) {
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs <= 0) throw new TypeError('invalid_media_timeout');
  const startedAt = performance.now();
  let actual: Decision = 'unavailable';
  let reason: Reason = 'unsupported_or_invalid';
  const isAudio = isRecord(sample) && sample.kind === 'audio';
  const scope = isAudio ? 'transcribed_speech_only' : 'image_and_extracted_text';
  if (validSample(sample) && (sample.kind !== 'image' || ports.checkImage)) {
    const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined;
    const run = async (): Promise<{ actual: Decision; reason: Reason }> => {
      const visual = sample.kind === 'image'
        ? contentSafetyDecisionFrom(await ports.checkImage!(sample, controller.signal)) : 'allow';
      controller.signal.throwIfAborted();
      const extraction = await ports.extractText(sample, controller.signal);
      controller.signal.throwIfAborted();
      if (!isRecord(extraction)) return { actual: 'unavailable', reason: 'extraction_incomplete' };
      if (sample.kind === 'image' && extraction.status === 'no_text' && extraction.text === '') {
        return { actual: visual, reason: 'completed' };
      }
      if (extraction.status !== 'complete' || extraction.language !== 'ko'
        || (sample.kind === 'audio' && extraction.speechDetected !== true)
        || typeof extraction.text !== 'string' || !extraction.text.trim()
        || extraction.text.length > 20_000) {
        return { actual: 'unavailable', reason: 'extraction_incomplete' };
      }
      const text = contentSafetyDecisionFrom(await ports.checkText(extraction.text, controller.signal));
      controller.signal.throwIfAborted();
      return { actual: visual === 'block' || text === 'block' ? 'block' : 'allow', reason: 'completed' };
    };
    try {
      const deadline = new Promise<never>((_resolve, reject) => {
        timer = setTimeout(() => { controller.abort(); reject(new Error()); }, timeoutMs);
      });
      ({ actual, reason } = await Promise.race([run(), deadline]));
    } catch {
      reason = controller.signal.aborted ? 'timeout' : 'provider_failure';
    } finally {
      clearTimeout(timer);
      controller.abort();
    }
  }
  return { actual, reason, scope, originalAudioCovered: false,
    latencyMs: Math.round(performance.now() - startedAt) };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function validSample(value: unknown): value is MediaSample {
  if (!isRecord(value) || typeof value.id !== 'string' || !/^[a-z0-9-]{1,80}$/.test(value.id)
    || !(value.bytes instanceof Uint8Array) || value.bytes.length === 0
    || value.bytes.length > 20 * 1024 * 1024) return false;
  return (value.kind === 'image' && ['image/png', 'image/jpeg', 'image/webp'].includes(String(value.mimeType)))
    || (value.kind === 'audio' && ['audio/wav', 'audio/mp4', 'audio/mpeg'].includes(String(value.mimeType)));
}

export function characterErrorRate(reference: string, observed: string): number {
  const normalize = (text: string) => Array.from(text.normalize('NFC').replace(/\s/g, ''));
  const a = normalize(reference);
  const b = normalize(observed);
  if (!a.length) return b.length ? 1 : 0;
  let previous = Array.from({ length: b.length + 1 }, (_, i) => i);
  for (let i = 1; i <= a.length; i++) {
    const row = [i];
    for (let j = 1; j <= b.length; j++) {
      row[j] = Math.min(row[j - 1]! + 1, previous[j]! + 1,
        previous[j - 1]! + (a[i - 1] === b[j - 1] ? 0 : 1));
    }
    previous = row;
  }
  return previous[b.length]! / a.length;
}

export function summarizeMediaEvaluation(rows: readonly {
  id: string; expected: Decision; actual: Decision; latencyMs: number;
  referenceText?: string; extractedText?: string;
  characterErrorRate?: number | null;
}[]) {
  if (!rows.length || new Set(rows.map(r => r.id)).size !== rows.length
    || rows.some(r => !/^[a-z0-9-]{1,80}$/.test(r.id)
      || !['allow', 'block', 'unavailable'].includes(r.expected)
      || !['allow', 'block', 'unavailable'].includes(r.actual)
      || !Number.isFinite(r.latencyMs) || r.latencyMs < 0
      || (r.characterErrorRate !== undefined && r.characterErrorRate !== null
        && (!Number.isFinite(r.characterErrorRate) || r.characterErrorRate < 0))
      || (r.referenceText !== undefined && r.referenceText.length > 2_000)
      || (r.extractedText !== undefined && r.extractedText.length > 2_000))) {
    throw new TypeError('invalid_media_evaluation_rows');
  }
  const results = rows.map(r => ({ id: r.id, expected: r.expected, actual: r.actual, latencyMs: r.latencyMs,
    characterErrorRate: r.characterErrorRate ?? (r.referenceText !== undefined && r.extractedText !== undefined
      ? characterErrorRate(r.referenceText, r.extractedText) : null) }));
  const latencies = rows.map(r => r.latencyMs).sort((a, b) => a - b);
  return { total: rows.length, correct: rows.filter(r => r.expected === r.actual).length,
    falseAllows: rows.filter(r => r.expected === 'block' && r.actual === 'allow').length,
    falseBlocks: rows.filter(r => r.expected === 'allow' && r.actual === 'block').length,
    unavailable: rows.filter(r => r.actual === 'unavailable').length,
    unexpectedApprovals: rows.filter(r => r.expected === 'unavailable' && r.actual === 'allow').length,
    extractionCompared: results.filter(r => r.characterErrorRate !== null).length,
    latencyP50Ms: latencies[Math.ceil(rows.length * 0.5) - 1],
    latencyP95Ms: latencies[Math.ceil(rows.length * 0.95) - 1], results };
}
