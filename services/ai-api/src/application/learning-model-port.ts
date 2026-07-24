import type {
  AnonymizedCompletedQuestionContext,
  CoupleFeedbackCandidate,
  DirectQuestionAnswer,
  DirectQuestionContext,
  FoundationQuestionCandidate,
  GeneralQuestionContext,
  ModelMemoryCandidate,
  PersonalizedQuestionCandidate,
  ProactiveSuggestionCandidate,
  ProactiveSuggestionContext,
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

export type LearningModelErrorCode =
  | 'model_rate_limited'
  | 'model_unavailable'
  | 'model_invalid_request'
  | 'model_auth_failed'
  | 'model_not_found'
  | 'model_request_failed'
  | 'model_timeout'
  | 'model_network_error'
  | 'model_invalid_output';

export class LearningModelError extends Error {
  readonly code: LearningModelErrorCode;
  readonly retryable: boolean;
  readonly providerHttpStatus: number | null;
  readonly providerErrorStatus: string | null;
  readonly diagnosticDetail: string | null;
  readonly retryAfterMs: number | null;
  readonly usage: LearningModelUsage;

  constructor(params: {
    code: LearningModelErrorCode;
    retryable: boolean;
    providerHttpStatus?: number | null;
    providerErrorStatus?: string | null;
    diagnosticDetail?: string | null;
    retryAfterMs?: number | null;
    usage?: LearningModelUsage;
    cause?: unknown;
  }) {
    super(params.code, { cause: params.cause });
    this.name = 'LearningModelError';
    this.code = params.code;
    this.retryable = params.retryable;
    this.providerHttpStatus = params.providerHttpStatus ?? null;
    this.providerErrorStatus = params.providerErrorStatus ?? null;
    this.diagnosticDetail = params.diagnosticDetail ?? null;
    this.retryAfterMs = params.retryAfterMs ?? null;
    this.usage = params.usage ?? {
      inputTokenCount: null,
      outputTokenCount: null,
      latencyMs: 0,
    };
  }
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

  generateGeneralQuestion(
    context: GeneralQuestionContext,
  ): Promise<LearningModelResult<PersonalizedQuestionCandidate>>;

  generatePersonalizedQuestion(
    context: AnonymizedCompletedQuestionContext,
  ): Promise<LearningModelResult<PersonalizedQuestionCandidate>>;

  answerDirectQuestion(
    context: DirectQuestionContext,
  ): Promise<LearningModelResult<DirectQuestionAnswer>>;

  generateProactiveSuggestion(
    context: ProactiveSuggestionContext,
  ): Promise<LearningModelResult<ProactiveSuggestionCandidate>>;
}
