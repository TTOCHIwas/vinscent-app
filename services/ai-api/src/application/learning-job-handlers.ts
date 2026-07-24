import {
  anonymizeCompletedQuestionContext,
  resolveMemoryCandidates,
  validateCoupleFeedback,
  validateDirectQuestionAnswer,
  validateGeneralQuestion,
  validatePersonalizedQuestion,
  validateQuestionRecommendation,
} from '../domain/learning-contract.ts';
import {
  LearningJobHandlerRegistry,
  type LearningJobExecution,
  type LearningJobHandler,
  type PreparedLearningJob,
} from './learning-job-handler.ts';
import {
  AiRepositoryError,
  type ClaimedLearningJob,
  type LearningJobRepository,
} from './learning-job-repository.ts';
import type {
  LearningModelPort,
  LearningModelUsage,
} from './learning-model-port.ts';

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

    return modelJob('memory-v6', async () => {
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

    return modelJob('feedback-v3', async () => {
      let rejectedText: string | null = null;
      let combinedUsage: LearningModelUsage | null = null;

      for (let attempt = 0; attempt < 2; attempt += 1) {
        const result = await this.#model.generateCoupleFeedback(
          context,
          { rejectedText },
        );
        combinedUsage = combinedUsage === null
          ? result.usage
          : combineUsage(combinedUsage, result.usage);

        try {
          validateCoupleFeedback(result.value);
          return {
            output: { feedback_text: result.value.text },
            usage: combinedUsage,
          };
        } catch (error) {
          if (attempt === 1) {
            throw error;
          }
          rejectedText = result.value.text;
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

    return modelJob('question-ranking-v2', async () => {
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

    return modelJob('general-question-v1', async () => {
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

    return modelJob('personalized-question-v2', async () => {
      const result = await this.#model.generatePersonalizedQuestion(context);
      validatePersonalizedQuestion(result.value);
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

    return modelJob('direct-question-v1', async () => {
      const result = await this.#model.answerDirectQuestion(context);
      validateDirectQuestionAnswer(result.value);
      return {
        output: { answer_text: result.value.text },
        usage: result.usage,
      };
    });
  }
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
