import type {
  CompletedQuestionContext,
  DirectQuestionContext,
  GeneralQuestionContext,
} from '../domain/learning-contract.ts';
import type { LearningModelUsage } from './learning-model-port.ts';

export type LearningJobType =
  | 'extract_memories'
  | 'generate_feedback'
  | 'select_curated_question'
  | 'generate_general_question'
  | 'generate_personalized_question'
  | 'answer_user_question'
  | 'rebuild_profile';

export interface ClaimedLearningJob {
  jobId: string;
  coupleId: string;
  sourceId: string | null;
  jobType: LearningJobType;
  attempt: number;
  leaseExpiresAt: string;
}

export interface RunSuccess {
  runId: string;
  output: Record<string, unknown>;
  usage: LearningModelUsage;
}

export interface RunFailure {
  runId: string;
  errorCode: string;
  safetyStatus: 'flagged' | 'error';
  retryable: boolean;
  providerHttpStatus: number | null;
  providerErrorStatus: string | null;
  providerErrorDetail: string | null;
  retryAfterMs: number | null;
  usage: LearningModelUsage;
}

export interface LearningJobRepository {
  claimJobs(workerId: string, limit: number): Promise<ClaimedLearningJob[]>;
  loadContext(jobId: string): Promise<CompletedQuestionContext>;
  loadGeneralQuestionContext(jobId: string): Promise<GeneralQuestionContext>;
  loadDirectQuestionContext(jobId: string): Promise<DirectQuestionContext>;
  startRun(
    job: ClaimedLearningJob,
    provider: string,
    model: string,
    promptVersion: string,
  ): Promise<string>;
  succeedRun(success: RunSuccess): Promise<boolean>;
  failRun(failure: RunFailure): Promise<boolean>;
  failClaimedJob(
    jobId: string,
    errorCode: string,
    retryable: boolean,
  ): Promise<boolean>;
  expandRebuild(jobId: string): Promise<boolean>;
}

export class AiRepositoryError extends Error {
  readonly code: string;
  readonly retryable: boolean;

  constructor(params: { code: string; retryable: boolean; cause?: unknown }) {
    super(params.code, { cause: params.cause });
    this.name = 'AiRepositoryError';
    this.code = params.code;
    this.retryable = params.retryable;
  }
}
