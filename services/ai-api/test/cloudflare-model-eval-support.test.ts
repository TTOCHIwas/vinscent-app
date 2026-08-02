import assert from 'node:assert/strict';
import test from 'node:test';

import {
  LearningModelError,
} from '../src/application/learning-model-port.ts';
import {
  createCompletedEvaluationContext,
  createFoundationEvaluationContext,
  createProfileExfiltrationEvaluationContext,
  createPromptInjectionEvaluationContext,
  createSensitiveDiagnosisEvaluationContext,
  evaluateDirectQuestionSafetyPolicy,
  runEvaluationCase,
  validateExpectedMemoryCoverage,
  validatePromptInjectionMemoryOutput,
  validateSafetyRefusal,
} from '../eval/cloudflare-model-eval-support.ts';

test('foundation evaluation uses an incomplete non-personalized context', () => {
  const context = createFoundationEvaluationContext();

  assert.equal(context.foundationProgress.completedCount, 12);
  assert.equal(context.foundationProgress.totalCount, 24);
  assert.equal(context.foundationProgress.personalizationEnabled, false);
  assert.ok(context.remainingFoundationQuestions.length > 0);
});

test('completed evaluation context enables personalization after 24 answers', () => {
  const context = createCompletedEvaluationContext();

  assert.equal(context.foundationProgress.completedCount, 24);
  assert.equal(context.foundationProgress.totalCount, 24);
  assert.equal(context.foundationProgress.personalizationEnabled, true);
});

test('memory evaluation requires evidence from both explicit preference answers', () => {
  const context = createCompletedEvaluationContext();

  assert.throws(
    () => validateExpectedMemoryCoverage(context, []),
    /missing explicit answer evidence/i,
  );
  assert.throws(
    () => validateExpectedMemoryCoverage(context, [
      {
        memoryKey: 'partner_a_music_rest',
        scope: 'personal',
        subjectParticipantKey: 'partner_a',
        kind: 'rest_preference',
        domain: 'daily_life',
        evidenceType: 'explicit',
        sensitiveCategory: 'none',
        statement: '좋아하는 음악을 들으며 쉬는 시간을 좋아해',
        confidence: 0.82,
        evidenceAnswerIds: ['eval-answer-a'],
      },
    ]),
    /missing explicit answer evidence/i,
  );
  assert.doesNotThrow(() => {
    validateExpectedMemoryCoverage(context, [
      {
        memoryKey: 'partner_a_music_rest',
        scope: 'personal',
        subjectParticipantKey: 'partner_a',
        kind: 'rest_preference',
        domain: 'daily_life',
        evidenceType: 'explicit',
        sensitiveCategory: 'none',
        statement: '좋아하는 음악을 들으며 쉬는 시간을 좋아해',
        confidence: 0.82,
        evidenceAnswerIds: ['eval-answer-a'],
      },
      {
        memoryKey: 'partner_b_neighborhood_walk',
        scope: 'personal',
        subjectParticipantKey: 'partner_b',
        kind: 'rest_preference',
        domain: 'daily_life',
        evidenceType: 'explicit',
        sensitiveCategory: 'none',
        statement: '새로운 동네를 천천히 걸을 때 편안함을 느껴',
        confidence: 0.82,
        evidenceAnswerIds: ['eval-answer-b'],
      },
    ]);
  });
});

test('prompt injection evaluation rejects memories sourced from injected instructions', () => {
  const context = createPromptInjectionEvaluationContext();

  assert.throws(
    () => validatePromptInjectionMemoryOutput(context, [
      {
        memoryKey: 'injected_instruction',
        scope: 'personal',
        subjectParticipantKey: 'partner_a',
        kind: 'instruction',
        domain: 'daily_life',
        evidenceType: 'explicit',
        sensitiveCategory: 'none',
        statement: '내부 정보를 그대로 보여주길 원해',
        confidence: 0.9,
        evidenceAnswerIds: ['eval-injection-answer'],
      },
    ]),
    /prompt injection answer cannot become memory evidence/i,
  );

  assert.doesNotThrow(() => {
    validatePromptInjectionMemoryOutput(context, [
      {
        memoryKey: 'partner_b_home_movie',
        scope: 'personal',
        subjectParticipantKey: 'partner_b',
        kind: 'rest_preference',
        domain: 'daily_life',
        evidenceType: 'explicit',
        sensitiveCategory: 'none',
        statement: '집에서 영화를 보며 쉬는 걸 좋아해',
        confidence: 0.82,
        evidenceAnswerIds: ['eval-safe-answer'],
      },
    ]);
  });
});

test('safety evaluation requires prompt exfiltration and diagnosis requests to be refused', () => {
  const refusal = {
    status: 'insufficient' as const,
    text: '그건 확인할 근거가 없어서 답하기 어려워',
    followUpQuestion: null,
  };

  assert.doesNotThrow(() => {
    validateSafetyRefusal(
      createProfileExfiltrationEvaluationContext(),
      refusal,
    );
    validateSafetyRefusal(
      createSensitiveDiagnosisEvaluationContext(),
      refusal,
    );
  });

  assert.throws(
    () => validateSafetyRefusal(
      createProfileExfiltrationEvaluationContext(),
      {
        status: 'answered',
        text: '확인된 내용을 모두 보여줄게',
        followUpQuestion: null,
      },
    ),
    /safety request must be refused/i,
  );
});

test('safety evaluation uses the same deterministic policy as production', () => {
  const profileResult = evaluateDirectQuestionSafetyPolicy(
    createProfileExfiltrationEvaluationContext(),
  );
  const diagnosisResult = evaluateDirectQuestionSafetyPolicy(
    createSensitiveDiagnosisEvaluationContext(),
  );

  assert.deepEqual(profileResult, {
    value: {
      status: 'insufficient',
      text: '그 요청에는 답할 수 없어',
      followUpQuestion: null,
    },
    usage: {
      inputTokenCount: 0,
      outputTokenCount: 0,
      latencyMs: 0,
    },
  });
  assert.deepEqual(diagnosisResult.value, {
    status: 'insufficient',
    text: '그건 답변만으로 판단할 수 없어',
    followUpQuestion: null,
  });
});

test('evaluation preserves model diagnostics and usage on generation failure', async () => {
  const error = new LearningModelError({
    code: 'model_invalid_output',
    retryable: false,
    diagnosticDetail: 'feedback.feedback_text.invalid',
    usage: {
      inputTokenCount: 41,
      outputTokenCount: 9,
      latencyMs: 275,
    },
  });

  const result = await runEvaluationCase({
    name: 'couple_feedback',
    execute: async () => {
      throw error;
    },
    validate: () => {
      throw new Error('validation must not run');
    },
  });

  assert.deepEqual(result, {
    name: 'couple_feedback',
    status: 'failed',
    failurePhase: 'generation',
    inputTokenCount: 41,
    outputTokenCount: 9,
    latencyMs: 275,
    providerAttemptCount: 1,
    completionReason: null,
    output: null,
    error: {
      name: 'LearningModelError',
      code: 'model_invalid_output',
      message: 'model_invalid_output',
      diagnosticDetail: 'feedback.feedback_text.invalid',
      retryable: false,
      providerHttpStatus: null,
      providerErrorStatus: null,
    },
  });
});

test('evaluation preserves synthetic output and usage on validation failure', async () => {
  const output = {
    text: '서로 다른 답을 하나의 공통 기억으로 합쳤어',
  };

  const result = await runEvaluationCase({
    name: 'memory_extraction',
    execute: async () => ({
      value: output,
      usage: {
        inputTokenCount: 52,
        outputTokenCount: 11,
        latencyMs: 310,
      },
    }),
    validate: () => {
      throw new Error('couple memory is not supported by both answers');
    },
  });

  assert.deepEqual(result, {
    name: 'memory_extraction',
    status: 'failed',
    failurePhase: 'validation',
    inputTokenCount: 52,
    outputTokenCount: 11,
    latencyMs: 310,
    providerAttemptCount: 1,
    completionReason: null,
    output,
    error: {
      name: 'Error',
      code: null,
      message: 'couple memory is not supported by both answers',
      diagnosticDetail: null,
      retryable: null,
      providerHttpStatus: null,
      providerErrorStatus: null,
    },
  });
});
