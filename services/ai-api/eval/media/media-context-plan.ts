import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createExpansionEvaluationPlan } from '../context/context-expansion-plan.ts';
import { contextRecord } from '../context/context-policy.ts';
import type { MediaContextCase } from './media-context-evaluation.ts';

const hash = (value: unknown) => createHash('sha256').update(JSON.stringify(value)).digest('hex');
export function loadMediaContextInventory() {
  const root = new URL('../fixtures/', import.meta.url);
  const manifest = JSON.parse(readFileSync(new URL('content-safety-media-ko.json', root), 'utf8'));
  if (manifest.syntheticOnly !== true || manifest.schemaVersion !== 2 || !Array.isArray(manifest.cases)
    || manifest.cases.length !== 24 || !Array.isArray(manifest.sourceVariants) || !Array.isArray(manifest.codecControls)) throw new Error('invalid_media_context_inventory');
  const all = [...manifest.cases, ...manifest.sourceVariants, ...manifest.codecControls];
  if (all.length !== 37 || new Set(all.map(c => c.id)).size !== 37) throw new Error('invalid_media_context_inventory');
  const files = new Map<string, Buffer>();
  for (const sample of all) {
    if (typeof sample.id !== 'string' || !/^[a-z0-9-]{1,80}$/.test(sample.id)
      || typeof sample.asset !== 'string' || !/^media-ko\/[a-z0-9-]+\.(png|jpg|webp|m4a|wav|bin|svg)$/.test(sample.asset)
      || typeof sample.sha256 !== 'string' || !/^[a-f0-9]{64}$/.test(sample.sha256)) throw new Error('invalid_media_context_inventory');
    const bytes = readFileSync(new URL(sample.asset, root));
    if (!bytes.length || bytes.length > 20 * 1024 * 1024 || createHash('sha256').update(bytes).digest('hex') !== sample.sha256) throw new Error('invalid_media_context_inventory');
    files.set(sample.id, bytes);
  }
  const cases: MediaContextCase[] = manifest.cases.map((c: any) => {
    if (!['image', 'audio'].includes(c.kind) || typeof c.mimeType !== 'string'
      || !['allow', 'block', 'unavailable'].includes(c.expected) || typeof c.referenceText !== 'string' || c.referenceText.length > 2000) throw new Error('invalid_media_context_inventory');
    return { part: { id: c.id, kind: c.kind, mimeType: c.mimeType, bytes: files.get(c.id)! }, sourceSha256: c.sha256,
      expected: c.expected, referenceText: c.referenceText,
      externalEligible: c.kind === 'image' ? ['image/png', 'image/jpeg', 'image/webp'].includes(c.mimeType) && !c.asset.endsWith('.bin')
        : c.preparation === 'local_speech_generated' };
  });
  if (cases.filter(c => c.externalEligible && c.part.kind === 'image').length !== 10
    || cases.filter(c => c.externalEligible && c.part.kind === 'audio').length !== 8) throw new Error('invalid_media_context_inventory');
  return { manifestSha256: hash(manifest), verifiedFiles: all.length, cases };
}

export function createMediaContextPlan(selection = 'both') {
  const inventory = loadMediaContextInventory(); const context = createExpansionEvaluationPlan(selection);
  const estimate = (input: number) => Number((context.models.reduce((sum, m) => sum + 18
    * (input * m.cacheWriteUsdPerMillion + 512 * m.outputUsdPerMillion) / 1_000_000, 0) + .009).toFixed(9));
  const plan = { schemaVersion: 1, protocolRevision: 1, scope: 'synthetic_media_context_only',
    mediaManifestSha256: inventory.manifestSha256, policyVersion: context.policyVersion, policySha256: context.policySha256,
    contextSchemaSha256: context.schemaSha256, contextRequestConfigurationSha256: context.requestConfigurationSha256,
    models: { visual: 'omni-moderation-latest', transcription: 'gpt-transcribe', context: context.models,
      ocr: 'Windows.Media.Ocr:ko', vad: 'silero-vad-v6.2', localProbeAsr: 'vosk-model-small-ko-0.22' },
    inputs: { syntheticCases: 24, verifiedFiles: inventory.verifiedFiles, imagesSentAtMost: 10, audioSentAtMost: 8,
      maximumAudioMinutes: 2, inventory: inventory.cases.map(c => ({ id: c.part.id, sourceSha256: c.sourceSha256, externalEligible: c.externalEligible })) },
    stageLimits: { visualRequests: 10, transcriptionRequests: 8, contextRequestsPerModel: 18 },
    limits: { maximumRequests: 18 + context.models.length * 18, retries: 0, extractionTimeoutMs: 30_000,
      perCandidateTimeoutMs: 20_000, maxInputBytes: 20 * 1024 * 1024, maximumAudioDurationMs: 15_000, maxOutputTokens: 512 },
    noTextPolicy: 'unavailable_without_independent_text_absence_evidence', sharedExtractionAcrossCandidates: true,
    estimatedUsd: estimate(2000), conservativeEstimatedUsd: estimate(10_000),
    estimateAssumptions: '18 context calls/model; 2000 input tokens/call, conservative 10000; 512 output; input cache-write allowance 1.25x; ASR <=2min at $0.0045/min; visual moderation free; not a hard billing cap; excludes taxes',
    generalTextSafetyCovered: false, ready: false, productionPublicationAuthorized: false,
    humanListeningPerformed: false, originalAudioCovered: false };
  return { ...plan, approvalFingerprint: hash(plan) };
}

export function createMediaContextBudget(selection = 'both', fetcher: typeof fetch = fetch) {
  const context = createExpansionEvaluationPlan(selection); const allowed = context.models.map(m => m.model);
  const counts = new Map<string, number>(); let stopped = false;
  const diagnostics: { stage: string; model: string; status: number | null; failure: string | null }[] = [];
  const budgeted: typeof fetch = async (url, init) => {
    if (stopped) throw new Error('media_context_budget_stopped');
    let stage: string; let model: string; let cap: number;
    try {
      if (String(url) === 'https://api.openai.com/v1/audio/transcriptions') {
        if (!(init?.body instanceof FormData) || init.body.get('model') !== 'gpt-transcribe') throw new Error();
        stage = 'transcription'; model = 'gpt-transcribe'; cap = 8;
      } else {
        const body: unknown = typeof init?.body === 'string' ? JSON.parse(init.body) : undefined;
        if (!contextRecord(body) || typeof body.model !== 'string') throw new Error();
        model = body.model;
        if (String(url) === 'https://api.openai.com/v1/moderations' && model === 'omni-moderation-latest') { stage = 'visual'; cap = 10; }
        else if (String(url) === 'https://api.openai.com/v1/responses' && allowed.includes(model)) { stage = 'context'; cap = 18; }
        else throw new Error();
      }
      const key = `${stage}:${model}`; const used = counts.get(key) ?? 0;
      if (used >= cap) throw new Error(); counts.set(key, used + 1);
    } catch { stopped = true; throw new Error('media_context_budget_stopped'); }
    const entry = { stage, model, status: null as number | null, failure: null as string | null }; diagnostics.push(entry);
    try {
      const response = await fetcher(url, init); entry.status = response.status;
      if (!response.ok) { stopped = true; entry.failure = 'http_error'; } return response;
    } catch { stopped = true; entry.failure = 'transport_error'; throw new Error('media_context_provider_unavailable'); }
  };
  return { fetcher: budgeted, diagnostics, isStopped: () => stopped };
}
