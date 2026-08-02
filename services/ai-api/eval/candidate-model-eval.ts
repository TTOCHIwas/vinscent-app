import {
  serializeEvaluationReport,
  writeEvaluationReport,
} from './cloudflare-evaluation-report.ts';
import {
  createModelEvaluationCases,
} from './cloudflare-model-eval-cases.ts';
import {
  createCandidateModelEvaluationPlan,
} from './candidate-model-eval-config.ts';
import {
  selectCandidateModelEvaluationCases,
} from './candidate-model-eval-suite.ts';
import {
  runModelEvaluation,
  type ModelEvaluationProgress,
} from './model-evaluation-runner.ts';

const plan = createCandidateModelEvaluationPlan(process.env);
const cases = selectCandidateModelEvaluationCases(
  createModelEvaluationCases(),
  plan.suite,
);
const execution = await runModelEvaluation({
  models: plan.models,
  cases,
  runs: plan.runs,
  onCaseComplete: writeProgress,
});
if (plan.outputPath !== null) {
  await writeEvaluationReport(plan.outputPath, execution.report);
}
process.stdout.write(serializeEvaluationReport(execution.report));

if (execution.hasFailure) {
  process.exitCode = 1;
}

function writeProgress(progress: ModelEvaluationProgress): void {
  const modelProgress = `${progress.modelIndex}/${progress.modelCount}`;
  const runProgress = `${progress.run}/${progress.runCount}`;
  const caseProgress = `${progress.caseIndex}/${progress.caseCount}`;
  const status = progress.result.status === 'failed'
    ? progress.result.operationalStatus === 'passed'
      ? 'recovered'
      : progress.result.servedStatus === 'passed'
      ? 'fallback'
      : 'failed'
    : 'passed';
  process.stderr.write(
    `[model ${modelProgress}] [run ${runProgress}] [case ${caseProgress}] `
      + `${progress.provider} ${progress.model} ${status}\n`,
  );
}
