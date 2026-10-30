import { createContextResumeSession, createContextResumePlan, evaluateContextResume } from './context/context-resume.ts';
import { createExpansionRequestBudget } from './context/context-expansion-plan.ts';
import { OpenAiContextExpansionCandidate } from './context/openai-context-expansion-candidate.ts';

try {
  const args = process.argv.slice(2);
  if (args.some(a => !/^(--live|--approved-plan=[a-f0-9]{64})$/.test(a))
    || new Set(args.map(a => a.split('=')[0])).size !== args.length) throw new Error('invalid_context_resume_arguments');
  const session = createContextResumeSession(); const plan = createContextResumePlan(session);
  if (!args.includes('--live')) console.log(JSON.stringify({ mode: 'plan', networkRequests: 0, ...plan }, null, 2));
  else {
    if (args.find(a => a.startsWith('--approved-plan='))?.slice(16) !== plan.approvalFingerprint) throw new Error('context_resume_approval_required');
    const apiKey = process.env.CONTENT_SAFETY_OPENAI_API_KEY?.trim();
    if (!apiKey) throw new Error('context_resume_credential_missing');
    const budget = createExpansionRequestBudget(plan.limits.maximumRequests);
    const candidates = plan.models.map(m => ({ id: m.id, model: m.model,
      port: new OpenAiContextExpansionCandidate({ apiKey, model: m.model, experiment: session.experiment, fetcher: budget.fetcher }) }));
    const result = await evaluateContextResume({ session, candidates });
    console.log(JSON.stringify({ mode: 'live', plan, additionalActualRequests: budget.diagnostics.length,
      cumulativeActualRequests: plan.priorActualRequests + budget.diagnostics.length,
      diagnostics: budget.diagnostics, circuitStopped: budget.isStopped(), ...result }, null, 2));
    if (result.additionalEvaluation.stoppedOnOperationalFailure || !result.combined.allScoredProposalsMatched) process.exitCode = 1;
  }
} catch (error) {
  const allowed = ['invalid_context_resume_arguments', 'context_resume_approval_required', 'context_resume_credential_missing'];
  console.error(JSON.stringify({ error: error instanceof Error && allowed.includes(error.message) ? error.message : 'context_resume_unavailable' }));
  process.exitCode = 1;
}
