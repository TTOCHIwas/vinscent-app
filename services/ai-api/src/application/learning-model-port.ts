import type {
  AnonymizedCompletedQuestionContext,
  CoupleFeedbackCandidate,
  CoupleFeedbackValidationCode,
  DirectQuestionAnswer,
  DirectQuestionContext,
  DirectQuestionFollowUpCandidate,
  DirectQuestionFollowUpValidationCode,
  FoundationQuestionCandidate,
  GeneralQuestionContext,
  ModelMemoryCandidate,
  PersonalizedQuestionCandidate,
  PersonalizedQuestionValidationCode,
  ProactiveSuggestionCandidate,
  ProactiveSuggestionContext,
  ProactiveSuggestionValidationCode,
} from '../domain/learning-contract.ts';
import type {
  KoreanOutputPolicyErrorCode,
} from '../domain/korean-output-policy.ts';

export interface FoundationQuestionRecommendation {
  questionKey: string;
  rationale: string;
}

export interface LearningModelUsage {
  inputTokenCount: number | null;
  outputTokenCount: number | null;
  latencyMs: number;
}

export interface LearningModelDiagnostics {
  providerAttemptCount: number;
  completionReason: string | null;
}

export interface LearningModelResult<T> {
  value: T;
  usage: LearningModelUsage;
  diagnostics?: LearningModelDiagnostics;
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
  | 'model_content_blocked'
  | 'model_invalid_output';

export class LearningModelError extends Error {
  readonly code: LearningModelErrorCode;
  readonly retryable: boolean;
  readonly providerHttpStatus: number | null;
  readonly providerErrorStatus: string | null;
  readonly diagnosticDetail: string | null;
  readonly retryAfterMs: number | null;
  readonly usage: LearningModelUsage;
  readonly diagnostics: LearningModelDiagnostics | null;

  constructor(params: {
    code: LearningModelErrorCode;
    retryable: boolean;
    providerHttpStatus?: number | null;
    providerErrorStatus?: string | null;
    diagnosticDetail?: string | null;
    retryAfterMs?: number | null;
    usage?: LearningModelUsage;
    diagnostics?: LearningModelDiagnostics | null;
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
    this.diagnostics = params.diagnostics ?? null;
  }
}

export interface CoupleFeedbackGenerationOptions {
  rejectedText: string | null;
  rejectionCode:
    | CoupleFeedbackValidationCode
    | KoreanOutputPolicyErrorCode
    | 'candidate_validation_failed'
    | null;
}

export interface PersonalizedQuestionGenerationOptions {
  rejectedText: string | null;
  rejectionCode:
    | PersonalizedQuestionValidationCode
    | KoreanOutputPolicyErrorCode
    | 'candidate_validation_failed'
    | null;
}

export interface ProactiveSuggestionGenerationOptions {
  rejectedText: string | null;
  rejectionCode:
    | ProactiveSuggestionValidationCode
    | 'candidate_validation_failed'
    | 'invalid_structure'
    | null;
}

export interface DirectQuestionFollowUpGenerationOptions {
  rejectedText: string | null;
  rejectionCode:
    | DirectQuestionFollowUpValidationCode
    | 'candidate_validation_failed'
    | null;
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
    options?: PersonalizedQuestionGenerationOptions,
  ): Promise<LearningModelResult<PersonalizedQuestionCandidate>>;

  answerDirectQuestion(
    context: DirectQuestionContext,
  ): Promise<LearningModelResult<DirectQuestionAnswer>>;

  generateDirectQuestionFollowUp(
    context: DirectQuestionContext,
    options?: DirectQuestionFollowUpGenerationOptions,
  ): Promise<LearningModelResult<DirectQuestionFollowUpCandidate>>;

  generateProactiveSuggestion(
    context: ProactiveSuggestionContext,
    options?: ProactiveSuggestionGenerationOptions,
  ): Promise<LearningModelResult<ProactiveSuggestionCandidate>>;
}
