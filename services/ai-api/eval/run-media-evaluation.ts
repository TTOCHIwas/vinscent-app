import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { NativeMediaRuntime } from './media/native-media-runtime.ts';
import { MediaExtractionAdapter } from './media/media-extraction-adapter.ts';
import { OpenAiTranscriptionAdapter } from './media/openai-transcription-adapter.ts';
import { mediaEvaluationPlan, createRequestBudget } from './media/media-evaluation-plan.ts';
import { evaluateMediaSafety, characterErrorRate, summarizeMediaEvaluation } from './media-safety-evaluation.ts';
import { OpenAiContentSafetyProvider } from '../src/infrastructure/openai-content-safety-provider.ts';
import { CloudflareContentSafetyProvider } from '../src/infrastructure/cloudflare-content-safety-provider.ts';

try {
  const args = process.argv.slice(2);
  if (args.some(a => !/^(--live|--provider=(openai|cloudflare)|--asr=(openai|local)|--approved-plan=[a-f0-9]{64})$/.test(a))
    || new Set(args.map(a => a.split('=')[0])).size !== args.length) throw new Error('invalid_media_arguments');
  const providerName = args.find(a => a.startsWith('--provider='))?.slice(11) ?? 'openai';
  const asr = args.find(a => a.startsWith('--asr='))?.slice(6) ?? 'openai';
  const manifestUrl = new URL('./fixtures/content-safety-media-ko.json', import.meta.url);
  const manifestBytes = readFileSync(manifestUrl);
  const manifest = JSON.parse(manifestBytes.toString('utf8'));
  const plan = mediaEvaluationPlan(createHash('sha256').update(manifestBytes).digest('hex'), providerName, asr);
  if (!args.includes('--live')) {
    console.log(JSON.stringify({ mode: 'plan', networkRequests: 0, ...plan }, null, 2));
  } else {
    if (args.find(a => a.startsWith('--approved-plan='))?.slice(16) !== plan.approvalFingerprint) {
      throw new Error('media_plan_approval_required');
    }
    const runtime = new NativeMediaRuntime({ python: required('CONTENT_SAFETY_PYTHON'),
      vadModel: required('CONTENT_SAFETY_VAD_MODEL'), asrModel: required('CONTENT_SAFETY_ASR_MODEL') });
    if (manifest.syntheticOnly !== true || manifest.cases.length !== 24
      || new Set(manifest.cases.map((c: { id: string }) => c.id)).size !== 24) throw new Error('invalid_media_inventory');
    const root = new URL('./fixtures/', import.meta.url);
    const prepared = [];
    for (const sample of manifest.cases) {
      if (!/^media-ko\/[a-z0-9-]+\.(png|jpg|webp|m4a|wav|bin|svg)$/.test(sample.asset)) throw new Error('invalid_media_inventory');
      const bytes = readFileSync(new URL(sample.asset, root));
      if (createHash('sha256').update(bytes).digest('hex') !== sample.sha256) throw new Error('invalid_media_inventory');
      const part = { id: sample.id, kind: sample.kind, mimeType: sample.mimeType, bytes };
      let decodeFailed = false;
      try {
        if (part.kind === 'image') {
          const image = await runtime.decodeImage(part, AbortSignal.timeout(20_000)) as { pngBase64: string };
          part.bytes = Buffer.from(image.pngBase64, 'base64'); part.mimeType = 'image/png';
        } else await runtime.decodeAudio(part, AbortSignal.timeout(20_000));
      } catch { decodeFailed = true; }
      if (decodeFailed && sample.expected !== 'unavailable') throw new Error('media_preflight_decode_failed');
      prepared.push({ sample, part, decodeFailed });
    }
    const silence = prepared.find(p => p.sample.id === 'audio-silence');
    if (!silence) throw new Error('invalid_media_inventory');
    const decodedSilence = await runtime.decodeAudio(silence.part, AbortSignal.timeout(20_000)) as Parameters<typeof runtime.detectSpeech>[0];
    await runtime.detectSpeech(decodedSilence, AbortSignal.timeout(20_000));
    const knownImage = prepared.find(p => p.sample.id === 'image-normal-ko');
    if (!knownImage) throw new Error('invalid_media_inventory');
    const decodedImage = await runtime.decodeImage(knownImage.part, AbortSignal.timeout(20_000));
    await runtime.ocr(decodedImage, AbortSignal.timeout(20_000));
    if (asr === 'local') await runtime.transcribe(decodedSilence, AbortSignal.timeout(20_000));
    const budget = createRequestBudget(plan.limits.maximumRequests);
    const classifier = providerName === 'openai'
      ? new OpenAiContentSafetyProvider({ apiKey: required('CONTENT_SAFETY_OPENAI_API_KEY'), fetcher: budget.fetcher })
      : new CloudflareContentSafetyProvider({ accountId: required('CONTENT_SAFETY_CLOUDFLARE_ACCOUNT_ID'),
        apiToken: required('CONTENT_SAFETY_CLOUDFLARE_API_TOKEN'), fetcher: budget.fetcher });
    const transcription = asr === 'openai'
      ? new OpenAiTranscriptionAdapter({ apiKey: required('CONTENT_SAFETY_OPENAI_API_KEY'), fetcher: budget.fetcher }) : runtime;
    const extractor = new MediaExtractionAdapter({ decodeAudio: runtime.decodeAudio.bind(runtime),
      decodeImage: runtime.decodeImage.bind(runtime), ocr: runtime.ocr.bind(runtime),
      detectSpeech: runtime.detectSpeech.bind(runtime), transcribe: transcription.transcribe.bind(transcription) });
    const results = [];
    for (const { sample, part, decodeFailed } of prepared) {
      if (budget.isStopped()) break;
      const start = performance.now();
      let observed: string | undefined;
      const extractText = async (p: typeof part, signal: AbortSignal) => {
        const result = await extractor.extract(p, signal);
        if ('text' in result && typeof result.text === 'string') observed = result.text;
        return result;
      };
      let textActual: string | null = null;
      const checkText = async (text: string, signal: AbortSignal) => {
        const result = await classifier.check({ id: part.id, kind: 'text', text }, signal);
        textActual = result.decision; return result;
      };
      let result;
      if (decodeFailed) result = { actual: 'unavailable' as const, reason: 'decode_failed', scope: 'not_evaluated' };
      else if (part.kind === 'image' && providerName === 'cloudflare') {
        const signal = AbortSignal.timeout(plan.limits.perCaseTimeoutMs);
        try {
          const extraction = await extractText(part, signal);
          if (extraction.status === 'complete' && 'text' in extraction) await checkText(extraction.text!, signal);
          result = { actual: 'unavailable' as const, reason: 'unsupported_visual_classifier', scope: 'extracted_text_only' };
        } catch { result = { actual: 'unavailable' as const, reason: 'provider_failure', scope: 'extracted_text_only' }; }
      } else result = await evaluateMediaSafety(part, { extractText, checkText,
        checkImage: (p, signal) => classifier.check({ ...p, kind: 'image' }, signal) }, plan.limits.perCaseTimeoutMs);
      results.push({ id: sample.id, expected: sample.expected, ...result, textActual,
        sourceSha256: sample.sha256, latencyMs: Math.round(performance.now() - start),
        characterErrorRate: observed === undefined ? null : characterErrorRate(sample.referenceText, observed) });
    }
    console.log(JSON.stringify({ generatedAt: new Date().toISOString(), plan, actualRequests: budget.diagnostics.length,
      circuitStopped: budget.isStopped(), diagnostics: budget.diagnostics, completedCases: results.length,
      originalAudioCovered: false, humanListeningPerformed: false, providerSelected: false,
      summary: results.length ? summarizeMediaEvaluation(results) : null, results }, null, 2));
    if (budget.isStopped() || results.length !== 24 || results.some(r => r.actual !== r.expected)) process.exitCode = 1;
  }
} catch (error) {
  const allowed = ['invalid_media_arguments', 'media_plan_approval_required', 'invalid_media_inventory', 'media_preflight_decode_failed', 'media_runtime_environment_missing'];
  const code = error instanceof Error && allowed.includes(error.message) ? error.message : 'media_evaluation_failed';
  console.error(JSON.stringify({ error: code })); process.exitCode = 1;
}
function required(name: string) { const value = process.env[name]?.trim(); if (!value) throw new Error('media_runtime_environment_missing'); return value; }
