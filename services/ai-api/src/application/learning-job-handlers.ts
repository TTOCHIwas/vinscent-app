import {
  anonymizeCompletedQuestionContext,
  CoupleFeedbackValidationError,
  DirectQuestionFollowUpValidationError,
  PersonalizedQuestionValidationError,
  resolveCoupleFeedbackFallback,
  resolveMemoryCandidates,
  type DirectQuestionAnswer,
  type DirectQuestionContext,
  type DirectQuestionFollowUpValidationCode,
  validateCoupleFeedback,
  validateDirectQuestionAnswer,
  validateDirectQuestionFollowUp,
  validateGeneralQuestion,
  validatePersonalizedQuestion,
  validateQuestionRecommendation,
} from '../domain/learning-contract.ts';
import {
  resolveDirectQuestionRefusal,
} from '../domain/direct-question-policy.ts';
import {
  reconcileDirectQuestionAnswer,
} from '../domain/direct-question-evidence.ts';
import {
  areQuestionsNearDuplicate,
} from '../domain/question-duplicate-detector.ts';
import {
  LearningJobHandlerRegistry,
  type LearningJobExecution,
  type LearningJobHandler,
  type PreparedLearningJob,
} from './learning-job-handler.ts';
import { LearningJobExecutionError } from './learning-job-execution-error.ts';
import {
  AiRepositoryError,
  type ClaimedLearningJob,
  type LearningJobRepository,
} from './learning-job-repository.ts';
import {
  LearningModelError,
  type CoupleFeedbackGenerationOptions,
  type LearningModelErrorCode,
  type LearningModelPort,
  type LearningModelUsage,
  type PersonalizedQuestionGenerationOptions,
} from './learning-model-port.ts';
import {
  koreanOutputRejectionCode,
  rejectedModelTextForRetry,
} from './model-output-retry.ts';

interface DefaultLearningJobHandlerOptions {
  repository: LearningJobRepository;
  model: LearningModelPort;
}

export function createDefaultLearningJobHandlerRegistry(
  options: DefaultLearningJobHandlerOptions,
): LearningJobHandlerRegistry {
  return new LearningJobHandlerRegistry([
    new ExtractMemoriesHandler(options),
    new GenerateFeedbackHandler(options),
    new SelectCuratedQuestionHandler(options),
    new GenerateGeneralQuestionHandler(options),
    new GeneratePersonalizedQuestionHandler(options),
    new AnswerUserQuestionHandler(options),
    new RebuildProfileHandler(options.repository),
  ]);
}

class ExtractMemoriesHandler implements LearningJobHandler {
  readonly jobType = 'extract_memories';
  readonly #repository: LearningJobRepository;
  readonly #model: LearningModelPort;

  constructor(options: DefaultLearningJobHandlerOptions) {
    this.#repository = options.repository;
    this.#model = options.model;
  }

  async prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob> {
    const context = await this.#repository.loadContext(job.jobId);
    const modelContext = anonymizeCompletedQuestionContext(context);

    return modelJob('memory-v8', async () => {
      const result = await this.#model.extractMemoryCandidates(modelContext);
      const memories = resolveMemoryCandidates(
        context,
        result.value.filter(
          (candidate) => candidate.sensitiveCategory === 'none',
        ),
      );

      return {
        output: {
          memories: memories.map((memory) => ({
            memory_key: memory.memoryKey,
            scope: memory.scope,
            subject_user_id: memory.subjectUserId,
            kind: memory.kind,
            learning_domain: memory.domain,
            evidence_type: memory.evidenceType,
            sensitive_category: memory.sensitiveCategory,
            statement: memory.statement,
            confidence: memory.confidence,
            evidence_answer_ids: memory.evidenceAnswerIds,
          })),
        },
        usage: result.usage,
      };
    });
  }
}

class GenerateFeedbackHandler implements LearningJobHandler {
  readonly jobType = 'generate_feedback';
  readonly #repository: LearningJobRepository;
  readonly #model: LearningModelPort;

  constructor(options: DefaultLearningJobHandlerOptions) {
    this.#repository = options.repository;
    this.#model = options.model;
  }

  async prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob> {
    const context = anonymizeCompletedQuestionContext(
      await this.#repository.loadContext(job.jobId),
    );

    return modelJob('feedback-v7', async () => {
      let rejectedText: string | null = null;
      let rejectionCode: CoupleFeedbackGenerationOptions['rejectionCode'] =
        null;
      const rejectionCodes: Array<NonNullable<
        CoupleFeedbackGenerationOptions['rejectionCode']
      >> = [];
      let combinedUsage: LearningModelUsage | null = null;

      for (let attempt = 0; attempt < 2; attempt += 1) {
        const result = await this.#model.generateCoupleFeedback(
          context,
          { rejectedText, rejectionCode },
        );
        combinedUsage = combinedUsage === null
          ? result.usage
          : combineUsage(combinedUsage, result.usage);

        try {
          validateCoupleFeedback(result.value, context);
          return {
            output: { feedback_text: result.value.text },
            usage: combinedUsage,
          };
        } catch (error) {
          const currentRejectionCode = coupleFeedbackRejectionCode(error);
          rejectionCodes.push(currentRejectionCode);
          if (attempt === 1) {
            if (currentRejectionCode === 'mixed_certainty_content') {
              const fallback = resolveCoupleFeedbackFallback(
                context,
                currentRejectionCode,
              );
              if (fallback !== null) {
                validateCoupleFeedback(fallback, context);
                return {
                  output: { feedback_text: fallback.text },
                  usage: combinedUsage,
                };
              }
            }
            throw new LearningJobExecutionError({
              code: coupleFeedbackFailureCode(rejectionCodes),
              retryable: false,
              usage: combinedUsage,
              cause: error,
            });
          }
          rejectionCode = currentRejectionCode;
          rejectedText = rejectedModelTextForRetry(
            result.value.text,
            rejectionCode,
          );
        }
      }

      throw new Error('couple feedback generation exhausted');
    });
  }
}

class SelectCuratedQuestionHandler implements LearningJobHandler {
  readonly jobType = 'select_curated_question';
  readonly #repository: LearningJobRepository;
  readonly #model: LearningModelPort;

  constructor(options: DefaultLearningJobHandlerOptions) {
    this.#repository = options.repository;
    this.#model = options.model;
  }

  async prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob> {
    const context = await this.#repository.loadContext(job.jobId);
    const modelContext = anonymizeCompletedQuestionContext(context);

    return modelJob('question-ranking-v3', async () => {
      const result = await this.#model.rankFoundationQuestions(
        modelContext,
        context.remainingFoundationQuestions,
      );
      validateQuestionRecommendation(
        context.remainingFoundationQuestions,
        result.value.questionKey,
      );

      return {
        output: {
          question_key: result.value.questionKey,
          rationale: requireNonBlank(
            result.value.rationale,
            'question rationale',
            500,
          ),
        },
        usage: result.usage,
      };
    });
  }
}

class GenerateGeneralQuestionHandler implements LearningJobHandler {
  readonly jobType = 'generate_general_question';
  readonly #repository: LearningJobRepository;
  readonly #model: LearningModelPort;

  constructor(options: DefaultLearningJobHandlerOptions) {
    this.#repository = options.repository;
    this.#model = options.model;
  }

  async prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob> {
    const context = await this.#repository.loadGeneralQuestionContext(
      job.jobId,
    );

    return modelJob('general-question-v2', async () => {
      const result = await this.#model.generateGeneralQuestion(context);
      validateGeneralQuestion(result.value);
      return {
        output: {
          question_key: result.value.questionKey,
          question_text: result.value.text,
          category: result.value.category,
          mood: result.value.mood,
          rationale: result.value.rationale,
        },
        usage: result.usage,
      };
    });
  }
}

class GeneratePersonalizedQuestionHandler implements LearningJobHandler {
  readonly jobType = 'generate_personalized_question';
  readonly #repository: LearningJobRepository;
  readonly #model: LearningModelPort;

  constructor(options: DefaultLearningJobHandlerOptions) {
    this.#repository = options.repository;
    this.#model = options.model;
  }

  async prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob> {
    const context = anonymizeCompletedQuestionContext(
      await this.#repository.loadContext(job.jobId),
    );

    return modelJob('personalized-question-v5', async () => {
      let rejectedText: string | null = null;
      let rejectionCode:
        PersonalizedQuestionGenerationOptions['rejectionCode'] = null;
      let combinedUsage: LearningModelUsage | null = null;

      for (let attempt = 0; attempt < 2; attempt += 1) {
        const result = await this.#model.generatePersonalizedQuestion(
          context,
          { rejectedText, rejectionCode },
        );
        combinedUsage = combinedUsage === null
          ? result.usage
          : combineUsage(combinedUsage, result.usage);

        try {
          validatePersonalizedQuestion(result.value);
          return {
            output: {
              question_key: result.value.questionKey,
              question_text: result.value.text,
              category: result.value.category,
              mood: result.value.mood,
              rationale: result.value.rationale,
            },
            usage: combinedUsage,
          };
        } catch (error) {
          if (attempt === 1) {
            throw error;
          }
          rejectionCode = personalizedQuestionRejectionCode(error);
          rejectedText = rejectedModelTextForRetry(
            result.value.text,
            rejectionCode,
          );
        }
      }

      throw new Error('personalized question generation exhausted');
    });
  }
}

function coupleFeedbackRejectionCode(
  error: unknown,
): NonNullable<CoupleFeedbackGenerationOptions['rejectionCode']> {
  if (error instanceof CoupleFeedbackValidationError) {
    return error.code;
  }
  return koreanOutputRejectionCode(error) ?? 'candidate_validation_failed';
}

function coupleFeedbackFailureCode(
  rejectionCodes: ReadonlyArray<NonNullable<
    CoupleFeedbackGenerationOptions['rejectionCode']
  >>,
): string {
  if (rejectionCodes.length !== 2) {
    throw new RangeError(
      'couple feedback rejection history must contain 2 codes',
    );
  }
  return `feedback_rejected_a1_${rejectionCodes[0]}_a2_${rejectionCodes[1]}`;
}

function personalizedQuestionRejectionCode(
  error: unknown,
): NonNullable<PersonalizedQuestionGenerationOptions['rejectionCode']> {
  if (error instanceof PersonalizedQuestionValidationError) {
    return error.code;
  }
  return koreanOutputRejectionCode(error) ?? 'candidate_validation_failed';
}

class AnswerUserQuestionHandler implements LearningJobHandler {
  readonly jobType = 'answer_user_question';
  readonly #repository: LearningJobRepository;
  readonly #model: LearningModelPort;

  constructor(options: DefaultLearningJobHandlerOptions) {
    this.#repository = options.repository;
    this.#model = options.model;
  }

  async prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob> {
    const context = await this.#repository.loadDirectQuestionContext(job.jobId);

    return modelJob('direct-question-v9', async () => {
      const result = await generateDirectQuestionAnswer(
        this.#model,
        context,
      );
      const answer = result.answer;
      return {
        output: {
          answer_status: answer.status,
          answer_text: answer.text,
          follow_up_generation_status: result.followUpGenerationStatus,
          follow_up_error_code: result.followUpErrorCode,
          follow_up_question: answer.followUpQuestion === null
            ? null
            : {
                question_key: answer.followUpQuestion.questionKey,
                question_text: answer.followUpQuestion.text,
                category: answer.followUpQuestion.category,
                mood: answer.followUpQuestion.mood,
                rationale: answer.followUpQuestion.rationale,
              },
        },
        usage: result.usage,
      };
    });
  }
}

async function generateDirectQuestionAnswer(
  model: LearningModelPort,
  context: DirectQuestionContext,
): Promise<{
  answer: DirectQuestionAnswer;
  followUpGenerationStatus: DirectQuestionFollowUpGenerationStatus;
  followUpErrorCode: DirectQuestionFollowUpErrorCode | null;
  usage: LearningModelUsage;
}> {
  const refusalText = resolveDirectQuestionRefusal(context.questionText);
  if (refusalText !== null) {
    const answer: DirectQuestionAnswer = {
      status: 'insufficient',
      text: refusalText,
      followUpQuestion: null,
    };
    validateDirectQuestionAnswer(context, answer);
    return {
      answer,
      followUpGenerationStatus: 'not_applicable',
      followUpErrorCode: null,
      usage: {
        inputTokenCount: 0,
        outputTokenCount: 0,
        latencyMs: 0,
      },
    };
  }

  const firstResult = await model.answerDirectQuestion(context);
  const firstAnswer = reconcileDirectQuestionAnswer(context, {
    ...firstResult.value,
    followUpQuestion: null,
  });
  validateDirectQuestionAnswer(context, firstAnswer);
  if (firstAnswer.status !== 'insufficient') {
    return {
      answer: firstAnswer,
      followUpGenerationStatus: 'not_applicable',
      followUpErrorCode: null,
      usage: firstResult.usage,
    };
  }

  const hasEquivalentSharedQuestion = context.recentSharedQuestionTexts.some(
    (questionText) => areQuestionsNearDuplicate(
      context.questionText,
      questionText,
    ),
  );
  if (hasEquivalentSharedQuestion) {
    return {
      answer: firstAnswer,
      followUpGenerationStatus: 'duplicate',
      followUpErrorCode: 'duplicate_question',
      usage: firstResult.usage,
    };
  }

  let usage = firstResult.usage;
  let rejectedText: string | null = null;
  let rejectionCode: DirectQuestionFollowUpRetryCode | null = null;

  for (let attempt = 0; attempt < 2; attempt += 1) {
    let followUpResult: Awaited<
      ReturnType<LearningModelPort['generateDirectQuestionFollowUp']>
    >;
    try {
      followUpResult = await model.generateDirectQuestionFollowUp(
        context,
        { rejectedText, rejectionCode },
      );
    } catch (error) {
      if (error instanceof LearningModelError) {
        usage = combineUsage(usage, error.usage);
      }
      return {
        answer: firstAnswer,
        followUpGenerationStatus: 'generation_failed',
        followUpErrorCode: directQuestionFollowUpGenerationErrorCode(error),
        usage,
      };
    }

    usage = combineUsage(usage, followUpResult.usage);
    try {
      validateDirectQuestionFollowUp(context, followUpResult.value);
      return {
        answer: {
          ...firstAnswer,
          followUpQuestion: followUpResult.value,
        },
        followUpGenerationStatus: 'generated',
        followUpErrorCode: null,
        usage,
      };
    } catch (error) {
      const validationCode = error
          instanceof DirectQuestionFollowUpValidationError
        ? error.code
        : 'candidate_validation_failed';
      if (attempt === 1) {
        return {
          answer: firstAnswer,
          followUpGenerationStatus: validationCode === 'duplicate_question'
            ? 'duplicate'
            : 'candidate_invalid',
          followUpErrorCode: validationCode,
          usage,
        };
      }
      rejectedText = rejectedModelTextForRetry(
        followUpResult.value.text,
        validationCode,
      );
      rejectionCode = validationCode;
    }
  }

  throw new Error('direct question follow-up generation exhausted');
}

type DirectQuestionFollowUpGenerationStatus =
  | 'not_applicable'
  | 'generated'
  | 'generation_failed'
  | 'candidate_invalid'
  | 'duplicate';

type DirectQuestionFollowUpErrorCode =
  | DirectQuestionFollowUpRetryCode
  | LearningModelErrorCode
  | 'model_generation_failed';

type DirectQuestionFollowUpRetryCode =
  | DirectQuestionFollowUpValidationCode
  | 'candidate_validation_failed';

function directQuestionFollowUpGenerationErrorCode(
  error: unknown,
): DirectQuestionFollowUpErrorCode {
  return error instanceof LearningModelError
    ? error.code
    : 'model_generation_failed';
}

class RebuildProfileHandler implements LearningJobHandler {
  readonly jobType = 'rebuild_profile';
  readonly #repository: LearningJobRepository;

  constructor(repository: LearningJobRepository) {
    this.#repository = repository;
  }

  async prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob> {
    return {
      kind: 'maintenance',
      execute: async () => {
        const expanded = await this.#repository.expandRebuild(job.jobId);
        if (!expanded) {
          throw new AiRepositoryError({
            code: 'ai_rebuild_not_completed',
            retryable: true,
          });
        }
      },
    };
  }
}

function modelJob(
  promptVersion: string,
  execute: () => Promise<LearningJobExecution>,
): PreparedLearningJob {
  return {
    kind: 'model',
    promptVersion,
    execute,
  };
}

function combineUsage(
  first: LearningModelUsage,
  second: LearningModelUsage,
): LearningModelUsage {
  return {
    inputTokenCount: sumKnownCounts(
      first.inputTokenCount,
      second.inputTokenCount,
    ),
    outputTokenCount: sumKnownCounts(
      first.outputTokenCount,
      second.outputTokenCount,
    ),
    latencyMs: first.latencyMs + second.latencyMs,
  };
}

function sumKnownCounts(
  first: number | null,
  second: number | null,
): number | null {
  return first === null || second === null ? null : first + second;
}

function requireNonBlank(
  value: string,
  name: string,
  maximum: number,
): string {
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > maximum) {
    throw new RangeError(`${name} must contain 1 to ${maximum} characters`);
  }
  return normalized;
}
