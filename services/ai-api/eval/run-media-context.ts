import { createHash } from 'node:crypto';
import { loadMediaContextInventory, createMediaContextPlan, createMediaContextBudget } from './media/media-context-plan.ts';
import { evaluateMediaContextBatch } from './media/media-context-evaluation.ts';
import { NativeMediaRuntime } from './media/native-media-runtime.ts';
import { MediaExtractionAdapter } from './media/media-extraction-adapter.ts';
import { OpenAiTranscriptionAdapter } from './media/openai-transcription-adapter.ts';
import { OpenAiContentSafetyProvider } from '../src/infrastructure/openai-content-safety-provider.ts';
import { OpenAiContextExpansionCandidate } from './context/openai-context-expansion-candidate.ts';
import { createContextExpansionExperiment, buildExpansionRequest } from './context/context-expansion-experiment.ts';
import { characterErrorRate } from './media-safety-evaluation.ts';

try {
  const args = process.argv.slice(2);
  if (args.some(a => !/^(--live|--verify-local|--candidate=(luna|terra|both)|--approved-plan=[a-f0-9]{64})$/.test(a))
    || new Set(args.map(a => a.split('=')[0])).size !== args.length || (args.includes('--live') && args.includes('--verify-local'))) throw new Error('invalid_media_context_arguments');
  const selection = args.find(a => a.startsWith('--candidate='))?.slice(12) ?? 'both';
  const plan = createMediaContextPlan(selection);
  if (!args.includes('--live') && !args.includes('--verify-local')) console.log(JSON.stringify({ mode: 'plan', networkRequests: 0, ...plan }, null, 2));
  else {
    if (args.includes('--live') && args.find(a => a.startsWith('--approved-plan='))?.slice(16) !== plan.approvalFingerprint) throw new Error('media_context_approval_required');
    const runtime = new NativeMediaRuntime({ python: required('CONTENT_SAFETY_PYTHON'), vadModel: required('CONTENT_SAFETY_VAD_MODEL'), asrModel: required('CONTENT_SAFETY_ASR_MODEL') });
    const inventory = loadMediaContextInventory();
    const local = args.includes('--verify-local'); const budget = local ? undefined : createMediaContextBudget(selection);
    const transcription = local ? runtime : new OpenAiTranscriptionAdapter({ apiKey: required('CONTENT_SAFETY_OPENAI_API_KEY'), fetcher: budget!.fetcher });
    const extractor = new MediaExtractionAdapter({ decodeImage: runtime.decodeImage.bind(runtime), decodeAudio: runtime.decodeAudio.bind(runtime),
      ocr: runtime.ocr.bind(runtime), detectSpeech: runtime.detectSpeech.bind(runtime), transcribe: transcription.transcribe.bind(transcription) });
    const extractText = async (part: Parameters<typeof extractor.extract>[0], signal: AbortSignal) => {
      const row = inventory.cases.find(c => c.part.id === part.id)!;
      if (!row.externalEligible && !local) {
        const control = new MediaExtractionAdapter({ decodeImage: runtime.decodeImage.bind(runtime), decodeAudio: runtime.decodeAudio.bind(runtime),
          ocr: runtime.ocr.bind(runtime), detectSpeech: runtime.detectSpeech.bind(runtime), transcribe: async () => { throw new Error(); } });
        return control.extract(part, signal);
      }
      return extractor.extract(part, signal);
    };
    if (local) {
      const experiment = createContextExpansionExperiment();
      const results = [];
      for (const c of inventory.cases) {
        const value = await extractText(c.part, AbortSignal.timeout(30_000));
        const observed = 'text' in value && typeof value.text === 'string' ? value.text : undefined;
        const requestBodySha256ByModel = value.status === 'complete' && observed && c.externalEligible
          ? plan.models.context.map(m => ({ model: m.model,
            sha256: createHash('sha256').update(JSON.stringify(buildExpansionRequest(m.model, observed, experiment))).digest('hex') })) : [];
        results.push({ id: c.part.id, sourceSha256: c.sourceSha256, kind: c.part.kind, externalEligible: c.externalEligible,
          extractionStatus: value.status, observedTextSha256: observed ? createHash('sha256').update(observed).digest('hex') : null,
          characterErrorRate: observed === undefined ? null : characterErrorRate(c.referenceText, observed), requestBodySha256ByModel, humanReviewed: false });
      }
      const automaticTextQualityPassed = results.filter(r => r.externalEligible).every(r => r.extractionStatus === 'complete' && r.characterErrorRate === 0);
      console.log(JSON.stringify({ generatedAt: new Date().toISOString(), mode: 'local_extraction_only', networkRequests: 0, plan,
        contextRequestsPrepared: results.reduce((sum, r) => sum + r.requestBodySha256ByModel.length, 0),
        automaticTextQualityPassed, contextQualityEvaluated: false, generalTextSafetyCovered: false, ready: false,
        productionPublicationAuthorized: false, humanListeningPerformed: false, originalAudioCovered: false, results }, null, 2));
      if (!automaticTextQualityPassed) process.exitCode = 1;
    } else {
      const experiment = createContextExpansionExperiment();
      const visual = new OpenAiContentSafetyProvider({ apiKey: required('CONTENT_SAFETY_OPENAI_API_KEY'), fetcher: budget!.fetcher });
      const candidates = plan.models.context.map(m => ({ id: m.id, model: m.model,
        port: new OpenAiContextExpansionCandidate({ apiKey: required('CONTENT_SAFETY_OPENAI_API_KEY'), model: m.model, experiment, fetcher: budget!.fetcher }) }));
      const result = await evaluateMediaContextBatch(inventory.cases, { extractText, candidates,
        checkImage: (p, signal) => visual.check({ ...p, kind: 'image' }, signal) });
      console.log(JSON.stringify({ mode: 'live', plan, actualRequests: budget!.diagnostics.length, diagnostics: budget!.diagnostics,
        circuitStopped: budget!.isStopped(), ...result }, null, 2));
      if (result.stoppedOnOperationalFailure || result.results.length !== 24 * candidates.length || result.results.some(r => r.actual !== r.expected)) process.exitCode = 1;
    }
  }
} catch (error) {
  const allowed = ['invalid_media_context_arguments', 'media_context_approval_required', 'media_context_environment_missing'];
  console.error(JSON.stringify({ error: error instanceof Error && allowed.includes(error.message) ? error.message : 'media_context_evaluation_failed' })); process.exitCode = 1;
}
function required(name: string) { const value = process.env[name]?.trim(); if (!value) throw new Error('media_context_environment_missing'); return value; }
