import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const supabaseRoot = new URL('../../', import.meta.url);

test('AI learning worker composes the safe operational diagnostic logger', async () => {
  const source = await readFile(
    new URL('functions/process-ai-learning-jobs/index.ts', supabaseRoot),
    'utf8',
  );

  assert.match(source, /learning-job-diagnostic-logger\.ts/);
  assert.match(source, /onDiagnostic:\s*logLearningJobDiagnostic/);
});
