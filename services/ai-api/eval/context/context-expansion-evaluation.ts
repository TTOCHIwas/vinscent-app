import { createHash } from 'node:crypto';
import { contextLimits, contextModels, contextRecord, parseContextUsage, parseResolvedContextModel } from './context-policy.ts';
import { parseExpansionClassification, requireExpansionExperiment, type ContextExpansionExperiment } from './context-expansion-experiment.ts';

type Candidate = { id: string; model: string; port: { classify(text: string, signal: AbortSignal): Promise<unknown> } };
export async function evaluateContextExpansion(options: { experiment: ContextExpansionExperiment; candidates: readonly Candidate[]; timeoutMs?: number }) {
  requireExpansionExperiment(options.experiment);
  const timeoutMs = options.timeoutMs ?? contextLimits.timeoutMs;
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > contextLimits.timeoutMs
    || !Array.isArray(options.candidates) || options.candidates.length < 1 || options.candidates.length > 2
    || new Set(options.candidates.map(c => c.id)).size !== options.candidates.length) throw new Error('invalid_context_expansion_candidates');
  for (const candidate of options.candidates) {
    if (typeof candidate.id !== 'string' || !Object.hasOwn(contextModels, candidate.id)
      || candidate.model !== contextModels[candidate.id as keyof typeof contextModels]
      || typeof candidate.port?.classify !== 'function') throw new Error('invalid_context_expansion_candidates');
  }
  const results: { id: string; candidate: string; expected: 'allow' | 'block' | null; actual: string; intent: string | null;
    operationalStatus: string; errorCode: string | null; latencyMs: number; evidenceSha256: string[]; resolvedModel: string | null;
    usage: { inputTokens: number | null; outputTokens: number | null } }[] = [];
  let stoppedOnOperationalFailure = false;
  run: for (const sample of options.experiment.cases) for (const candidate of options.candidates) {
    const controller = new AbortController(); let timer: ReturnType<typeof setTimeout> | undefined;
    const started = performance.now();
    let row: typeof results[number] = { id: sample.id, candidate: candidate.id, expected: sample.expected, actual: 'unavailable', intent: null,
      operationalStatus: 'failed', errorCode: null, latencyMs: 0, evidenceSha256: [], resolvedModel: null,
      usage: { inputTokens: null, outputTokens: null } };
    try {
      const deadline = new Promise<never>((_resolve, reject) => { timer = setTimeout(() => { controller.abort(); reject(new Error()); }, timeoutMs); });
      const value = await Promise.race([candidate.port.classify(sample.text, controller.signal), deadline]);
      controller.signal.throwIfAborted(); if (!contextRecord(value)) throw new Error();
      const classification = parseExpansionClassification(value.classification, sample.text);
      const model = parseResolvedContextModel(value.resolvedModel, candidate.model); const usage = parseContextUsage(value.usage);
      row = { ...row, actual: classification.decision, intent: classification.intent, operationalStatus: 'completed',
        evidenceSha256: classification.evidence.map(e => createHash('sha256').update(e).digest('hex')), resolvedModel: model, usage };
    } catch { stoppedOnOperationalFailure = true; row.errorCode = controller.signal.aborted ? 'timeout' : 'candidate_failure'; }
    finally { clearTimeout(timer); controller.abort(); }
    row.latencyMs = Math.round(performance.now() - started); results.push(row);
    if (stoppedOnOperationalFailure) break run;
  }
  const models = options.candidates.map(candidate => {
    const rows = results.filter(r => r.candidate === candidate.id); const scored = rows.filter(r => r.expected !== null);
    const unresolved = rows.filter(r => r.expected === null); const times = rows.map(r => r.latencyMs).sort((a, b) => a - b);
    const complete = rows.length === 28 && rows.every(r => r.operationalStatus === 'completed');
    return { id: candidate.id, model: candidate.model, completedCases: rows.length, complete, plannedScoredCases: 24,
      scoredCases: scored.length, correct: scored.filter(r => r.actual === r.expected).length,
      falseAllows: scored.filter(r => r.expected === 'block' && r.actual === 'allow').length,
      falseBlocks: scored.filter(r => r.expected === 'allow' && r.actual === 'block').length,
      unavailable: scored.filter(r => r.actual === 'unavailable').length, unresolvedCases: unresolved.length,
      unresolvedModelAllows: unresolved.filter(r => r.actual === 'allow').length,
      scoredProposalsMatched: complete && scored.every(r => r.actual === r.expected),
      usageComplete: complete && rows.every(r => r.usage.inputTokens !== null && r.usage.outputTokens !== null),
      inputTokens: rows.length && rows.every(r => r.usage.inputTokens !== null) ? rows.reduce((s, r) => s + r.usage.inputTokens!, 0) : null,
      outputTokens: rows.length && rows.every(r => r.usage.outputTokens !== null) ? rows.reduce((s, r) => s + r.usage.outputTokens!, 0) : null,
      latencyP50Ms: times.length ? times[Math.ceil(times.length * .5) - 1] : null,
      latencyP95Ms: times.length ? times[Math.ceil(times.length * .95) - 1] : null };
  });
  return { generatedAt: new Date().toISOString(), scope: 'synthetic_context_expansion_text_only', policyVersion: options.experiment.policyVersion,
    policyStatus: 'proposal', packSha256: options.experiment.packSha256, humanLabelReviewsCompleted: 0, independentlyValidated: false,
    ready: false, productionPublicationAuthorized: false, humanListeningPerformed: false, originalAudioCovered: false,
    stoppedOnOperationalFailure, allScoredProposalsMatched: models.every(m => m.scoredProposalsMatched), models, results };
}
