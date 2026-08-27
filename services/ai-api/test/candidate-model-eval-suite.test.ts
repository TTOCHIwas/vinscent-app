import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createModelEvaluationCases,
} from '../eval/cloudflare-model-eval-cases.ts';
import {
  selectCandidateModelEvaluationCases,
} from '../eval/candidate-model-eval-suite.ts';

test('candidate smoke suite covers every service task once', () => {
  const allCases = createModelEvaluationCases();
  const smokeCases = selectCandidateModelEvaluationCases(allCases, 'smoke');

  assert.equal(smokeCases.length, 9);
  assert.equal(
    new Set(smokeCases.map((item) => item.task)).size,
    smokeCases.length,
  );
});

test('candidate full suite preserves all 56 evaluation cases', () => {
  const allCases = createModelEvaluationCases();
  const fullCases = selectCandidateModelEvaluationCases(allCases, 'full');

  assert.equal(fullCases.length, 56);
  assert.notEqual(fullCases, allCases);
  assert.deepEqual(fullCases, allCases);
});
