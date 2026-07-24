import type {
  ClaimedLearningJob,
  LearningJobType,
} from './learning-job-repository.ts';
import type { LearningModelUsage } from './learning-model-port.ts';

export interface LearningJobExecution {
  output: Record<string, unknown>;
  usage: LearningModelUsage;
}

export interface PreparedModelLearningJob {
  kind: 'model';
  promptVersion: string;
  execute(): Promise<LearningJobExecution>;
}

export interface PreparedMaintenanceLearningJob {
  kind: 'maintenance';
  execute(): Promise<void>;
}

export type PreparedLearningJob =
  | PreparedModelLearningJob
  | PreparedMaintenanceLearningJob;

export interface LearningJobHandler {
  readonly jobType: LearningJobType;
  prepare(job: ClaimedLearningJob): Promise<PreparedLearningJob>;
}

export class LearningJobHandlerRegistry {
  readonly #handlers = new Map<LearningJobType, LearningJobHandler>();

  constructor(handlers: Iterable<LearningJobHandler>) {
    for (const handler of handlers) {
      if (this.#handlers.has(handler.jobType)) {
        throw new RangeError(
          `duplicate learning job handler: ${handler.jobType}`,
        );
      }
      this.#handlers.set(handler.jobType, handler);
    }
  }

  handlerFor(jobType: LearningJobType): LearningJobHandler {
    const handler = this.#handlers.get(jobType);
    if (handler === undefined) {
      throw new RangeError(`learning job handler not found: ${jobType}`);
    }
    return handler;
  }
}
