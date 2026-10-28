import { createHash } from 'node:crypto';
import { contextLimits, contextModels, contextRecord, parseContextClassification, parseContextUsage,
  parseResolvedContextModel, requireContextText } from './context-policy.ts';

type Case = { readonly id: string; readonly group: string; readonly text: string;
  readonly expected: 'allow' | 'block' | 'unavailable'; readonly reviewStatus: string };
type Candidate = { id: string; model: string; port: { classify(text: string, signal: AbortSignal): Promise<unknown> } };
export async function evaluateContextCandidates(options: { cases: readonly Case[]; candidates: readonly Candidate[]; timeoutMs?: number }) {
  const timeoutMs = options.timeoutMs ?? contextLimits.timeoutMs;
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > contextLimits.timeoutMs
    || !options.cases.length || options.cases.length > 12 || new Set(options.cases.map(c => c.id)).size !== options.cases.length
    || !options.candidates.length || options.candidates.length > 2
    || new Set(options.candidates.map(c => c.id)).size !== options.candidates.length) throw new TypeError('invalid_context_evaluation');
  for (const sample of options.cases) {
    requireContextText(sample.text);
    if (typeof sample.id !== 'string' || !/^[a-z0-9-]{1,80}$/.test(sample.id) || sample.reviewStatus !== 'draft'
      || typeof sample.group !== 'string' || !sample.group.trim() || sample.group.length > 80
      || !['allow', 'block', 'unavailable'].includes(sample.expected)
      || (sample.expected === 'unavailable') !== (sample.group === 'unresolved_context')) throw new TypeError('invalid_context_evaluation');
  }
  for (const candidate of options.candidates) {
    if (typeof candidate.id !== 'string' || typeof candidate.model !== 'string'
      || !Object.hasOwn(contextModels, candidate.id) || contextModels[candidate.id as keyof typeof contextModels] !== candidate.model
      || typeof candidate.port?.classify !== 'function') throw new TypeError('invalid_context_evaluation');
  }
  const results: { id: string; candidate: string; expected: string | null; actual: string; intent: string | null;
    operationalStatus: string; errorCode: string | null; latencyMs: number; evidenceSha256: string[]; resolvedModel: string | null;
    usage: { inputTokens: number | null; outputTokens: number | null } }[] = [];
  let stoppedOnOperationalFailure = false;
  run: for (const sample of options.cases) {
    for (const candidate of options.candidates) {
      const controller = new AbortController();
      let timer: ReturnType<typeof setTimeout> | undefined;
      const started = performance.now();
      let row: typeof results[number] = { id: sample.id, candidate: candidate.id, expected: sample.expected === 'unavailable' ? null : sample.expected,
        actual: 'unavailable', intent: null, operationalStatus: 'failed', errorCode: null, latencyMs: 0,
        evidenceSha256: [], resolvedModel: null, usage: { inputTokens: null, outputTokens: null } };
      try {
        const deadline = new Promise<never>((_resolve, reject) => {
          timer = setTimeout(() => { controller.abort(); reject(new Error()); }, timeoutMs);
        });
        const value = await Promise.race([candidate.port.classify(sample.text, controller.signal), deadline]);
        controller.signal.throwIfAborted();
        if (!contextRecord(value)) throw new Error();
        const classification = parseContextClassification(value.classification, sample.text);
        row = { ...row, actual: classification.decision, intent: classification.intent, operationalStatus: 'completed',
          evidenceSha256: classification.evidence.map(e => createHash('sha256').update(e).digest('hex')),
          resolvedModel: parseResolvedContextModel(value.resolvedModel, candidate.model), usage: parseContextUsage(value.usage) };
      } catch {
        stoppedOnOperationalFailure = true;
        row.errorCode = controller.signal.aborted ? 'timeout' : 'candidate_failure';
      } finally { clearTimeout(timer); controller.abort(); }
      row.latencyMs = Math.round(performance.now() - started); results.push(row);
      if (stoppedOnOperationalFailure) break run;
    }
  }
  const models = options.candidates.map(candidate => {
    const rows = results.filter(r => r.candidate === candidate.id);
    const scored = rows.filter(r => r.expected !== null);
    const unresolved = rows.filter(r => r.expected === null);
    const latencies = rows.map(r => r.latencyMs).sort((a, b) => a - b);
    const complete = rows.length === options.cases.length && rows.every(r => r.operationalStatus === 'completed');
    return { id: candidate.id, model: candidate.model, completedCases: rows.length, complete,
      plannedScoredCases: options.cases.filter(c => c.expected !== 'unavailable').length,
      scoredCases: scored.length, correct: scored.filter(r => r.actual === r.expected).length,
      falseAllows: scored.filter(r => r.expected === 'block' && r.actual === 'allow').length,
      falseBlocks: scored.filter(r => r.expected === 'allow' && r.actual === 'block').length,
      unavailable: scored.filter(r => r.actual === 'unavailable').length,
      unresolvedCases: unresolved.length, unresolvedModelAllows: unresolved.filter(r => r.actual === 'allow').length,
      scoredDraftLabelsPassed: complete && scored.every(r => r.actual === r.expected),
      usageComplete: complete && rows.every(r => r.usage.inputTokens !== null && r.usage.outputTokens !== null),
      inputTokens: rows.some(r => r.usage.inputTokens === null) || !rows.length ? null : rows.reduce((sum, r) => sum + r.usage.inputTokens!, 0),
      outputTokens: rows.some(r => r.usage.outputTokens === null) || !rows.length ? null : rows.reduce((sum, r) => sum + r.usage.outputTokens!, 0),
      latencyP50Ms: latencies.length ? latencies[Math.ceil(latencies.length * 0.5) - 1] : null,
      latencyP95Ms: latencies.length ? latencies[Math.ceil(latencies.length * 0.95) - 1] : null };
  });
  return { generatedAt: new Date().toISOString(), scope: 'synthetic_context_text_only', policyStatus: 'draft',
    ready: false, productionPublicationAuthorized: false, humanListeningPerformed: false, originalAudioCovered: false,
    stoppedOnOperationalFailure, allScoredDraftLabelsPassed: models.every(m => m.scoredDraftLabelsPassed), models, results };
}
