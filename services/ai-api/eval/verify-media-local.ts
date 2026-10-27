import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { NativeMediaRuntime } from './media/native-media-runtime.ts';
import { characterErrorRate } from './media-safety-evaluation.ts';

try {
  const root = new URL('./fixtures/', import.meta.url);
  const manifest = JSON.parse(readFileSync(new URL('content-safety-media-ko.json', root), 'utf8'));
  const runtime = new NativeMediaRuntime({ python: required('CONTENT_SAFETY_PYTHON'),
    vadModel: required('CONTENT_SAFETY_VAD_MODEL'), asrModel: required('CONTENT_SAFETY_ASR_MODEL') });
  const results = [];
  for (const sample of [...manifest.cases, ...manifest.codecControls]) {
    if (!/^media-ko\/[a-z0-9-]+\.(png|jpg|webp|wav|m4a|bin|svg)$/.test(sample.asset)) throw new Error();
    const bytes = readFileSync(new URL(sample.asset, root));
    if (createHash('sha256').update(bytes).digest('hex') !== sample.sha256) throw new Error();
    const signal = AbortSignal.timeout(20_000);
    let result: Record<string, unknown> = { id: sample.id, mimeType: sample.mimeType, sha256: sample.sha256,
      decode: 'failed', expectedDecodeFailure: sample.expected === 'unavailable' && !['audio-silence', 'audio-noise'].includes(sample.id),
      humanReviewed: false };
    try {
      if (sample.kind === 'image' || sample.mimeType.startsWith('image/')) {
        const decoded = await runtime.decodeImage({ ...sample, bytes }, signal);
        result.decode = 'passed';
        const observed = await runtime.ocr(decoded, signal) as { text: string };
        result.ocrCompared = true;
        result.characterErrorRate = characterErrorRate(sample.referenceText, observed.text);
        result.exactTextMatch = normalized(sample.referenceText) === normalized(observed.text);
      } else {
        const decoded = await runtime.decodeAudio({ ...sample, bytes }, signal) as { durationMs: number; wavBase64: string; sampleRate: number; samples: number };
        result.decode = 'passed'; result.durationMs = decoded.durationMs;
        const vad = await runtime.detectSpeech(decoded, signal) as { speechDetected: boolean; speechMs: number; maximumProbability: number };
        result.vad = vad;
        if (vad.speechDetected) {
          const observed = await runtime.transcribe(decoded, signal) as { text: string; confidence: number };
          result.asrCompared = true; result.minimumWordConfidence = observed.confidence;
          result.characterErrorRate = characterErrorRate(sample.referenceText, observed.text);
          result.exactTextMatch = normalized(sample.referenceText) === normalized(observed.text);
        }
      }
    } catch { result.failure = 'decode_or_extraction_unavailable'; }
    results.push(result);
  }
  const technicalVerificationPassed = !results.some(r => r.expectedDecodeFailure ? r.decode !== 'failed' : r.decode !== 'passed' || r.failure);
  const speechResults = results.filter(r => r.asrCompared);
  const automaticQualityPassed = technicalVerificationPassed && speechResults.length === 8
    && speechResults.every(r => r.exactTextMatch) && results.filter(r => r.ocrCompared).every(r => r.exactTextMatch)
    && results.filter(r => ['audio-silence', 'audio-noise'].includes(String(r.id))).every(r => (r.vad as { speechDetected: boolean })?.speechDetected === false);
  const report = { generatedAt: new Date().toISOString(), mode: 'local_automatic_verification', networkRequests: 0,
    technicalVerificationPassed, automaticQualityPassed,
    humanListeningPerformed: false, safetyQualityEvaluated: false, providerSelected: false,
    tools: { codec: 'PyAV 16.0.1 / Pillow 12.0.0', ocr: 'Windows.Media.Ocr ko',
      vad: 'Silero v6.2', asr: 'Vosk small-ko-0.22 (no grammar/prompt/reference input)' }, results };
  const output = new URL('../../../docs/release/content-safety-media-local-2026-10-27.json', import.meta.url);
  writeFileSync(output, JSON.stringify(report, null, 2) + '\n');
  console.log(JSON.stringify({ reportWritten: true, cases: results.length,
    decodePassed: results.filter(r => r.decode === 'passed').length,
    expectedDecodeFailures: results.filter(r => r.decode === 'failed' && r.expectedDecodeFailure).length,
    speechCompared: results.filter(r => r.asrCompared).length,
    speechExactMatches: results.filter(r => r.asrCompared && r.exactTextMatch).length,
    technicalVerificationPassed, automaticQualityPassed, humanListeningPerformed: false, networkRequests: 0 }));
  if (!automaticQualityPassed) process.exitCode = 1;
} catch { console.error(JSON.stringify({ error: 'local_media_verification_failed' })); process.exitCode = 1; }
function normalized(v: string) { return v.normalize('NFC').replace(/[\s.,!?]/g, ''); }
function required(name: string) { const v = process.env[name]?.trim(); if (!v) throw new Error(); return v; }
