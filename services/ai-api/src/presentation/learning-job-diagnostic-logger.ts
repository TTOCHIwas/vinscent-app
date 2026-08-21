import type {
  LearningJobOperationalDiagnostic,
} from '../application/process-learning-jobs.ts';

export function serializeLearningJobDiagnostic(
  diagnostic: LearningJobOperationalDiagnostic,
): string {
  return JSON.stringify({
    event: diagnostic.event,
    job_id: diagnostic.jobId,
    run_id: diagnostic.runId,
    job_attempt: diagnostic.jobAttempt,
    prompt_version: diagnostic.promptVersion,
    rejection_codes: [...diagnostic.rejectionCodes],
  });
}

export function logLearningJobDiagnostic(
  diagnostic: LearningJobOperationalDiagnostic,
): void {
  console.warn(serializeLearningJobDiagnostic(diagnostic));
}
