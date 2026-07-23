import type {
  AnonymizedCompletedQuestionContext,
  CoupleFeedbackCandidate,
  FoundationQuestionCandidate,
  ModelMemoryCandidate,
  PersonalizedQuestionCandidate,
} from '../domain/learning-contract.ts';

export interface FoundationQuestionRecommendation {
  questionKey: string;
  rationale: string;
}

export interface LearningModelUsage {
  inputTokenCount: number | null;
  outputTokenCount: number | null;
  latencyMs: number;
}

export interface LearningModelResult<T> {
  value: T;
  usage: LearningModelUsage;
}

export interface CoupleFeedbackGenerationOptions {
  rejectedText: string | null;
}

export interface LearningModelPort {
  rankFoundationQuestions(
    context: AnonymizedCompletedQuestionContext,
    candidates: FoundationQuestionCandidate[],
  ): Promise<LearningModelResult<FoundationQuestionRecommendation>>;

  extractMemoryCandidates(
    context: AnonymizedCompletedQuestionContext,
  ): Promise<LearningModelResult<ModelMemoryCandidate[]>>;

  generateCoupleFeedback(
    context: AnonymizedCompletedQuestionContext,
    options?: CoupleFeedbackGenerationOptions,
  ): Promise<LearningModelResult<CoupleFeedbackCandidate>>;

  generatePersonalizedQuestion(
    context: AnonymizedCompletedQuestionContext,
  ): Promise<LearningModelResult<PersonalizedQuestionCandidate>>;
}
