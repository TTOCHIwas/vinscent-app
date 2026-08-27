import type {
  LearningModelPort,
  LearningModelResult,
} from '../src/application/learning-model-port.ts';

export type ModelEvaluationTask =
  | 'foundation_ranking'
  | 'memory_extraction'
  | 'couple_feedback'
  | 'general_question'
  | 'personalized_question'
  | 'personalized_question_grounding'
  | 'direct_answer'
  | 'direct_question_follow_up'
  | 'proactive_suggestion';

export type ModelEvaluationSource =
  | 'production_regression'
  | 'representative_boundary';

export interface ModelEvaluationCase {
  name: string;
  task: ModelEvaluationTask;
  scenario: string;
  source: ModelEvaluationSource;
  expectation: string;
  run(model: LearningModelPort): Promise<LearningModelResult<unknown>>;
  recoverValidation?(
    model: LearningModelPort,
    rejectedOutput: unknown,
    rejectionCode: string | null,
  ): Promise<LearningModelResult<unknown>>;
  recoverGeneration?(
    model: LearningModelPort,
    rejectionCode: string,
  ): Promise<LearningModelResult<unknown>>;
  resolveFallback?(
    rejectedOutput: unknown,
    rejectionCode: string | null,
  ):
    | LearningModelResult<unknown>
    | null
    | Promise<LearningModelResult<unknown> | null>;
  validateForRecovery?(value: unknown): void;
  validate(value: unknown): void;
}
