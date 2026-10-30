import { createHash } from 'node:crypto';
import { evaluateMediaSafety, characterErrorRate, type MediaSample } from '../media-safety-evaluation.ts';
import { contextModels, contextRecord, parseContextUsage, parseResolvedContextModel } from '../context/context-policy.ts';
import { parseExpansionClassification } from '../context/context-expansion-experiment.ts';

type Ports = { model: string; extractText(part: MediaSample, signal: AbortSignal): Promise<unknown>;
  checkImage?(part: MediaSample, signal: AbortSignal): Promise<unknown>; classifyText(text: string, signal: AbortSignal): Promise<unknown> };
const textHash = (text: string) => createHash('sha256').update(text).digest('hex');
export async function evaluateMediaContext(sample: unknown, ports: Ports, timeoutMs = 20_000) {
  if (!(Object.values(contextModels) as string[]).includes(ports.model)) throw new Error('invalid_media_context_model');
  let extractionStatus: string | null = null; let observedTextSha256: string | null = null;
  let context: ReturnType<typeof parseExpansionClassification> | undefined;
  let usage: ReturnType<typeof parseContextUsage> = { inputTokens: null, outputTokens: null };
  let resolvedModel: string | null = null; let contextLatencyMs: number | null = null; let visualDecision: string | null = null;
  const safeSample = contextRecord(sample) && typeof sample.mimeType === 'string' ? sample : undefined;
  const result = await evaluateMediaSafety(safeSample, {
    checkImage: ports.checkImage ? async (part, signal) => {
      const value = await ports.checkImage!(part, signal);
      if (!contextRecord(value) || !['allow', 'block'].includes(value.decision as string)) throw new Error();
      visualDecision = value.decision as string; return value;
    } : undefined,
    extractText: async (part, signal) => {
      const value = await ports.extractText(part, signal);
      extractionStatus = contextRecord(value) && typeof value.status === 'string' ? value.status : 'invalid';
      if (contextRecord(value) && typeof value.text === 'string' && value.text.trim()) observedTextSha256 = textHash(value.text);
      return extractionStatus === 'no_text' ? { status: 'partial' } : value;
    },
    checkText: async (text, signal) => {
      const started = performance.now();
      const value = await ports.classifyText(text, signal);
      signal.throwIfAborted();
      if (!contextRecord(value)) throw new Error();
      const parsed = parseExpansionClassification(value.classification, text);
      const actualUsage = parseContextUsage(value.usage); const actualModel = parseResolvedContextModel(value.resolvedModel, ports.model);
      context = parsed; usage = actualUsage; resolvedModel = actualModel;
      contextLatencyMs = Math.round(performance.now() - started);
      return { decision: parsed.decision };
    },
  }, timeoutMs);
  const reason = result.reason !== 'timeout' && context?.decision === 'unavailable' ? 'context_unresolved'
    : result.reason === 'extraction_incomplete' && extractionStatus === 'no_text' ? 'no_text_unverified' : result.reason;
  return { ...result, reason, extractionStatus, observedTextSha256, visualDecision,
    contextDecision: context?.decision ?? null, contextIntent: context?.intent ?? null,
    contextEvidenceSha256: context?.evidence.map(textHash) ?? [], contextLatencyMs, resolvedModel, usage,
    operationalFailure: reason === 'provider_failure' || reason === 'timeout'
      || extractionStatus === 'failed' || extractionStatus === 'timeout',
    generalTextSafetyCovered: false, ready: false, productionPublicationAuthorized: false };
}

export type MediaContextCase = { part: MediaSample; sourceSha256: string; expected: 'allow' | 'block' | 'unavailable';
  referenceText: string; externalEligible: boolean };
type Candidate = { id: string; model: string; port: { classify(text: string, signal: AbortSignal): Promise<unknown> } };
export async function evaluateMediaContextBatch(cases: readonly MediaContextCase[], ports: {
  extractText: Ports['extractText']; checkImage: NonNullable<Ports['checkImage']>; candidates: readonly Candidate[];
}, timeoutMs = 20_000) {
  if (!cases.length || cases.length > 24 || new Set(cases.map(c => c.part.id)).size !== cases.length
    || !ports.candidates.length || ports.candidates.length > 2 || new Set(ports.candidates.map(c => c.id)).size !== ports.candidates.length) throw new Error('invalid_media_context_batch');
  for (const row of cases) {
    const part = row.part;
    if (typeof row.externalEligible !== 'boolean' || typeof row.expected !== 'string' || !['allow', 'block', 'unavailable'].includes(row.expected)
      || typeof row.referenceText !== 'string' || row.referenceText.length > 2000 || typeof row.sourceSha256 !== 'string'
      || !(part.bytes instanceof Uint8Array) || !part.bytes.length || part.bytes.length > 20 * 1024 * 1024
      || typeof part.id !== 'string' || !/^[a-z0-9-]{1,80}$/.test(part.id) || typeof part.mimeType !== 'string'
      || !['image', 'audio'].includes(part.kind) || createHash('sha256').update(part.bytes).digest('hex') !== row.sourceSha256
      || (row.externalEligible && !(part.kind === 'image' ? ['image/png', 'image/jpeg', 'image/webp'] : ['audio/wav', 'audio/mp4', 'audio/mpeg']).includes(part.mimeType)))
      throw new Error('invalid_media_context_batch');
  }
  for (const c of ports.candidates) if (typeof c.id !== 'string' || !Object.hasOwn(contextModels, c.id)
    || c.model !== contextModels[c.id as keyof typeof contextModels] || typeof c.port?.classify !== 'function') throw new Error('invalid_media_context_batch');
  const results: ({ id: string; candidate: string; expected: MediaContextCase['expected']; sourceSha256: string; characterErrorRate: number | null;
    extractionLatencyMs: number; commonExtractionStatus: string } & Awaited<ReturnType<typeof evaluateMediaContext>>)[] = [];
  let stoppedOnOperationalFailure = false;
  run: for (const row of cases) {
    const { id, kind, mimeType, bytes } = row.part; const part = { id, kind, mimeType, bytes };
    const started = performance.now(); const controller = new AbortController();
    let timer: ReturnType<typeof setTimeout> | undefined; let extracted: unknown;
    try {
      const deadline = new Promise<never>((_resolve, reject) => { timer = setTimeout(() => { controller.abort(); reject(new Error()); }, 30_000); });
      extracted = await Promise.race([ports.extractText(part, controller.signal), deadline]);
    } catch { extracted = { status: controller.signal.aborted ? 'timeout' : 'failed' }; }
    finally { clearTimeout(timer); controller.abort(); }
    const extractionLatencyMs = Math.round(performance.now() - started);
    const observed = contextRecord(extracted) && typeof extracted.text === 'string' ? extracted.text : undefined;
    let visual: Promise<unknown> | undefined;
    for (const candidate of ports.candidates) {
      const blockedExternal = !row.externalEligible || (contextRecord(extracted) && ['failed', 'timeout'].includes(extracted.status as string));
      const result = await evaluateMediaContext(part, { model: candidate.model,
        extractText: async () => blockedExternal ? { status: 'unsupported' } : extracted,
        checkImage: blockedExternal ? undefined : (p, signal) => visual ??= ports.checkImage(p, signal),
        classifyText: candidate.port.classify.bind(candidate.port),
      }, timeoutMs);
      if (row.externalEligible && blockedExternal) result.operationalFailure = true;
      results.push({ id, candidate: candidate.id, expected: row.expected, sourceSha256: row.sourceSha256,
        characterErrorRate: observed === undefined ? null : characterErrorRate(row.referenceText, observed), extractionLatencyMs,
        commonExtractionStatus: contextRecord(extracted) && typeof extracted.status === 'string' ? extracted.status : 'invalid', ...result });
      if (result.operationalFailure) { stoppedOnOperationalFailure = true; break run; }
    }
  }
  return { generatedAt: new Date().toISOString(), scope: 'media_visual_and_context_experiment',
    stoppedOnOperationalFailure, plannedCases: cases.length, results,
    ready: false, productionPublicationAuthorized: false, generalTextSafetyCovered: false,
    humanListeningPerformed: false, originalAudioCovered: false };
}
