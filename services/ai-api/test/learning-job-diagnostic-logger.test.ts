import assert from 'node:assert/strict';
import test from 'node:test';

import {
  serializeLearningJobDiagnostic,
} from '../src/presentation/learning-job-diagnostic-logger.ts';

test('feedback fallback diagnostics serialize only operational metadata', () => {
  const serialized = serializeLearningJobDiagnostic({
    event: 'ai_learning_feedback_fallback',
    jobId: 'job-123',
    runId: 'run-456',
    jobAttempt: 2,
    promptVersion: 'feedback-v11',
    rejectionCodes: ['ungrounded_detail', 'invalid_punctuation'],
  });

  assert.deepEqual(JSON.parse(serialized), {
    event: 'ai_learning_feedback_fallback',
    job_id: 'job-123',
    run_id: 'run-456',
    job_attempt: 2,
    prompt_version: 'feedback-v11',
    rejection_codes: ['ungrounded_detail', 'invalid_punctuation'],
  });
  assert.equal(serialized.includes('question'), false);
  assert.equal(serialized.includes('answer'), false);
  assert.equal(serialized.includes('feedback_text'), false);
  assert.equal(serialized.includes('user_id'), false);
  assert.equal(serialized.includes('couple_id'), false);
});
