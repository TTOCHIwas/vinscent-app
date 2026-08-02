import type {
  ModelEvaluationCase,
  ModelEvaluationTask,
} from './cloudflare-model-eval-case.ts';

export type CandidateModelEvaluationSuite = 'smoke' | 'full';

export function selectCandidateModelEvaluationCases(
  cases: ModelEvaluationCase[],
  suite: CandidateModelEvaluationSuite,
): ModelEvaluationCase[] {
  if (suite === 'full') {
    return [...cases];
  }

  const selected = new Map<ModelEvaluationTask, ModelEvaluationCase>();
  for (const evaluationCase of cases) {
    const current = selected.get(evaluationCase.task);
    if (
      current === undefined
      || (
        current.source !== 'production_regression'
        && evaluationCase.source === 'production_regression'
      )
    ) {
      selected.set(evaluationCase.task, evaluationCase);
    }
  }
  return [...selected.values()];
}
