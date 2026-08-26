import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createQuestionSimilarityEvaluationScenarios,
} from '../eval/question-similarity-eval-cases.ts';
import {
  evaluateHybridQuestionSimilarityLeaveOneGroupOut,
  evaluateQuestionSimilarityLeaveOneGroupOutAtPrecision,
  selectHybridQuestionSimilarityThresholdAtPrecision,
  selectQuestionSimilarityThreshold,
  selectQuestionSimilarityThresholdAtPrecision,
} from '../eval/question-similarity-eval-metrics.ts';

test('question similarity evaluation separates paraphrases, topic overlap, and hard negatives', () => {
  const scenarios = createQuestionSimilarityEvaluationScenarios();
  const comparisons = scenarios.flatMap((scenario) => scenario.comparisons);
  const relationCounts = Object.groupBy(
    comparisons,
    ({ relation }) => relation,
  );

  assert.ok(scenarios.length >= 10);
  assert.ok(comparisons.length >= 40);
  assert.ok((relationCounts.near_duplicate?.length ?? 0) >= 10);
  assert.ok((relationCounts.topic_overlap?.length ?? 0) >= 10);
  assert.ok((relationCounts.distinct?.length ?? 0) >= 20);
  assert.ok(scenarios.some((scenario) =>
    scenario.candidate === '다음 주말에 둘이 같이 해보고 싶은 영화는 뭐야?'
    && scenario.comparisons.some((comparison) =>
      comparison.question
        === '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?'
      && comparison.relation === 'topic_overlap'
    )
  ));
  assert.ok(comparisons.some((comparison) =>
    comparison.question.includes('작품')
    && comparison.relation === 'near_duplicate'
  ));
  assert.ok(comparisons.some((comparison) =>
    comparison.question === '둘이 함께 먹고 싶은 메뉴는 뭐야?'
    && comparison.relation === 'distinct'
  ));
});

test('question similarity threshold selection maximizes F1 without avoidable false positives', () => {
  const result = selectQuestionSimilarityThreshold([
    { score: 0.91, sameTopic: true },
    { score: 0.8, sameTopic: true },
    { score: 0.7, sameTopic: false },
    { score: 0.2, sameTopic: false },
  ]);

  assert.equal(result.threshold, 0.8);
  assert.deepEqual(result.metrics, {
    truePositive: 2,
    falsePositive: 0,
    trueNegative: 2,
    falseNegative: 0,
    precision: 1,
    recall: 1,
    f1: 1,
    accuracy: 1,
  });
});

test('precision-first threshold preserves the precision floor before maximizing recall', () => {
  const pairs = [
    { score: 0.91, sameTopic: true },
    { score: 0.8, sameTopic: true },
    { score: 0.6, sameTopic: true },
    { score: 0.7, sameTopic: false },
    { score: 0.2, sameTopic: false },
  ];

  assert.equal(selectQuestionSimilarityThreshold(pairs).threshold, 0.6);
  assert.deepEqual(
    selectQuestionSimilarityThresholdAtPrecision(pairs, 0.95),
    {
      threshold: 0.8,
      metrics: {
        truePositive: 2,
        falsePositive: 0,
        trueNegative: 2,
        falseNegative: 1,
        precision: 1,
        recall: 2 / 3,
        f1: 0.8,
        accuracy: 0.8,
      },
    },
  );
});

test('precision-first threshold reports when no useful threshold meets the floor', () => {
  assert.equal(selectQuestionSimilarityThresholdAtPrecision([
    { score: 0.9, sameTopic: false },
    { score: 0.8, sameTopic: true },
  ], 1), null);
});

test('hybrid threshold combines complementary high-confidence signals', () => {
  const result = selectHybridQuestionSimilarityThresholdAtPrecision([
    {
      rawScore: 0.9,
      focusScore: 0.4,
      lexicalSameTopic: false,
      sameTopic: true,
    },
    {
      rawScore: 0.6,
      focusScore: 0.8,
      lexicalSameTopic: false,
      sameTopic: true,
    },
    {
      rawScore: 0.2,
      focusScore: 0.2,
      lexicalSameTopic: true,
      sameTopic: true,
    },
    {
      rawScore: 0.75,
      focusScore: 0.3,
      lexicalSameTopic: false,
      sameTopic: false,
    },
    {
      rawScore: 0.4,
      focusScore: 0.7,
      lexicalSameTopic: false,
      sameTopic: false,
    },
  ], 0.95);

  assert.deepEqual(result, {
    rawThreshold: 0.9,
    focusThreshold: 0.8,
    metrics: {
      truePositive: 3,
      falsePositive: 0,
      trueNegative: 2,
      falseNegative: 0,
      precision: 1,
      recall: 1,
      f1: 1,
      accuracy: 1,
    },
  });
});

test('leave-one-group-out evaluation calibrates without the held-out scenario', () => {
  const result = evaluateQuestionSimilarityLeaveOneGroupOutAtPrecision([
    { groupId: 'a', score: 0.8, sameTopic: true },
    { groupId: 'a', score: 0.2, sameTopic: false },
    { groupId: 'b', score: 0.8, sameTopic: true },
    { groupId: 'b', score: 0.2, sameTopic: false },
    { groupId: 'c', score: 0.8, sameTopic: true },
    { groupId: 'c', score: 0.85, sameTopic: false },
  ], 1);

  assert.deepEqual(result.metrics, {
    truePositive: 1,
    falsePositive: 1,
    trueNegative: 2,
    falseNegative: 2,
    precision: 0.5,
    recall: 1 / 3,
    f1: 0.4,
    accuracy: 0.5,
  });
  assert.deepEqual(
    result.folds.map(({ groupId, threshold }) => ({ groupId, threshold })),
    [
      { groupId: 'a', threshold: null },
      { groupId: 'b', threshold: null },
      { groupId: 'c', threshold: 0.8 },
    ],
  );
});

test('hybrid leave-one-group-out evaluation reports every held-out prediction', () => {
  const pairs = [
    {
      groupId: 'raw',
      rawScore: 0.9,
      focusScore: 0.2,
      lexicalSameTopic: false,
      sameTopic: true,
    },
    {
      groupId: 'raw',
      rawScore: 0.2,
      focusScore: 0.2,
      lexicalSameTopic: false,
      sameTopic: false,
    },
    {
      groupId: 'focus',
      rawScore: 0.2,
      focusScore: 0.9,
      lexicalSameTopic: false,
      sameTopic: true,
    },
    {
      groupId: 'focus',
      rawScore: 0.2,
      focusScore: 0.2,
      lexicalSameTopic: false,
      sameTopic: false,
    },
    {
      groupId: 'lexical',
      rawScore: 0.2,
      focusScore: 0.2,
      lexicalSameTopic: true,
      sameTopic: true,
    },
    {
      groupId: 'lexical',
      rawScore: 0.2,
      focusScore: 0.2,
      lexicalSameTopic: false,
      sameTopic: false,
    },
  ];

  const result = evaluateHybridQuestionSimilarityLeaveOneGroupOut(pairs, 1);

  assert.equal(result.folds.length, 3);
  for (const fold of result.folds) {
    assert.notEqual(fold.rawThreshold, null);
    assert.notEqual(fold.focusThreshold, null);
  }
  assert.equal(
    result.metrics.truePositive
      + result.metrics.falsePositive
      + result.metrics.trueNegative
      + result.metrics.falseNegative,
    pairs.length,
  );
});
