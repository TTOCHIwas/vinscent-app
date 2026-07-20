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

export interface LearningModelPort {
  rankFoundationQuestions(
    context: AnonymizedCompletedQuestionContext,
    candidates: FoundationQuestionCandidate[],
  ): Promise<FoundationQuestionRecommendation>;

  extractMemoryCandidates(
    context: AnonymizedCompletedQuestionContext,
  ): Promise<ModelMemoryCandidate[]>;

  generateCoupleFeedback(
    context: AnonymizedCompletedQuestionContext,
  ): Promise<CoupleFeedbackCandidate>;

  generatePersonalizedQuestion(
    context: AnonymizedCompletedQuestionContext,
  ): Promise<PersonalizedQuestionCandidate>;
}
