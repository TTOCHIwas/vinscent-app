import { createContextEvaluationPlan } from './context/context-evaluation-plan.ts';
import { evaluateContextCandidates } from './context/context-evaluation.ts';
import { OpenAiContextSafetyCandidate } from './context/openai-context-safety-candidate.ts';
import { contentSafetyContextCases } from './fixtures/content-safety-context-ko.ts';
import { createRequestBudget } from './media/media-evaluation-plan.ts';

try {
  const args = process.argv.slice(2);
  if (args.some(a => !/^(--live|--candidate=(luna|terra|both)|--approved-plan=[a-f0-9]{64})$/.test(a))
    || new Set(args.map(a => a.split('=')[0])).size !== args.length) throw new Error('invalid_context_arguments');
  const selection = args.find(a => a.startsWith('--candidate='))?.slice(12) ?? 'both';
  const plan = createContextEvaluationPlan(selection);
  if (!args.includes('--live')) console.log(JSON.stringify({ mode: 'plan', networkRequests: 0, ...plan }, null, 2));
  else {
    if (args.find(a => a.startsWith('--approved-plan='))?.slice(16) !== plan.approvalFingerprint) throw new Error('context_plan_approval_required');
    const apiKey = process.env.CONTENT_SAFETY_OPENAI_API_KEY?.trim();
    if (!apiKey) throw new Error('context_credential_missing');
    const budget = createRequestBudget(plan.limits.maximumRequests);
    const candidates = plan.models.map(m => ({ id: m.id, model: m.model,
      port: new OpenAiContextSafetyCandidate({ apiKey, model: m.model, fetcher: budget.fetcher }) }));
    const report = await evaluateContextCandidates({ cases: contentSafetyContextCases, candidates });
    console.log(JSON.stringify({ mode: 'live', plan, actualRequests: budget.diagnostics.length,
      diagnostics: budget.diagnostics, circuitStopped: budget.isStopped(), ...report }, null, 2));
    if (report.stoppedOnOperationalFailure || !report.allScoredDraftLabelsPassed) process.exitCode = 1;
  }
} catch (error) {
  const allowed = ['invalid_context_arguments', 'context_plan_approval_required', 'context_credential_missing'];
  console.error(JSON.stringify({ error: error instanceof Error && allowed.includes(error.message) ? error.message : 'context_evaluation_failed' }));
  process.exitCode = 1;
}
