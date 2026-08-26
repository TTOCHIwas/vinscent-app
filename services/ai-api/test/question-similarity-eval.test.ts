import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createQuestionSimilarityEvaluationScenarios,
} from '../eval/question-similarity-eval-cases.ts';
import {
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
