import { createContextExpansionExperiment } from './context/context-expansion-experiment.ts';
import { createExpansionEvaluationPlan, createExpansionRequestBudget } from './context/context-expansion-plan.ts';
import { OpenAiContextExpansionCandidate } from './context/openai-context-expansion-candidate.ts';
import { evaluateContextExpansion } from './context/context-expansion-evaluation.ts';

try {
  const args = process.argv.slice(2);
  if (args.some(a => !/^(--live|--candidate=(luna|terra|both)|--approved-plan=[a-f0-9]{64})$/.test(a))
    || new Set(args.map(a => a.split('=')[0])).size !== args.length) throw new Error('invalid_context_expansion_arguments');
  const experiment = createContextExpansionExperiment();
  const plan = createExpansionEvaluationPlan(args.find(a => a.startsWith('--candidate='))?.slice(12) ?? 'both', experiment);
  if (!args.includes('--live')) console.log(JSON.stringify({ mode: 'plan', networkRequests: 0, ...plan }, null, 2));
  else {
    if (args.find(a => a.startsWith('--approved-plan='))?.slice(16) !== plan.approvalFingerprint) throw new Error('context_expansion_approval_required');
    const apiKey = process.env.CONTENT_SAFETY_OPENAI_API_KEY?.trim();
    if (!apiKey) throw new Error('context_expansion_credential_missing');
    const budget = createExpansionRequestBudget(plan.limits.maximumRequests);
    const candidates = plan.models.map(m => ({ id: m.id, model: m.model,
      port: new OpenAiContextExpansionCandidate({ apiKey, model: m.model, experiment, fetcher: budget.fetcher }) }));
    const report = await evaluateContextExpansion({ experiment, candidates });
    console.log(JSON.stringify({ mode: 'live', plan, actualRequests: budget.diagnostics.length,
      diagnostics: budget.diagnostics, circuitStopped: budget.isStopped(), ...report }, null, 2));
    if (report.stoppedOnOperationalFailure || !report.allScoredProposalsMatched) process.exitCode = 1;
  }
} catch (error) {
  const allowed = ['invalid_context_expansion_arguments', 'context_expansion_approval_required', 'context_expansion_credential_missing'];
  console.error(JSON.stringify({ error: error instanceof Error && allowed.includes(error.message) ? error.message : 'context_expansion_evaluation_failed' }));
  process.exitCode = 1;
}
