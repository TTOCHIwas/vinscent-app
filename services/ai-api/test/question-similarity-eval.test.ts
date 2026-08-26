import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createQuestionSimilarityEvaluationScenarios,
} from '../eval/question-similarity-eval-cases.ts';
import {
  selectQuestionSimilarityThreshold,
} from '../eval/question-similarity-eval-metrics.ts';

test('question similarity evaluation covers Korean repeats and distinct topics', () => {
  const scenarios = createQuestionSimilarityEvaluationScenarios();
  const comparisons = scenarios.flatMap((scenario) => scenario.comparisons);
  const sameTopicCount = comparisons.filter((item) => item.sameTopic).length;
  const distinctTopicCount = comparisons.length - sameTopicCount;

  assert.ok(scenarios.length >= 10);
  assert.ok(comparisons.length >= 40);
  assert.ok(sameTopicCount >= 15);
  assert.ok(distinctTopicCount >= 15);
  assert.ok(scenarios.some((scenario) =>
    scenario.candidate === '다음 주말에 둘이 같이 해보고 싶은 영화는 뭐야?'
    && scenario.comparisons.some((comparison) =>
      comparison.question
        === '주말에 둘이 같이 영화 보러 갈 때 어떤 영화 장르를 좋아해?'
      && comparison.sameTopic
    )
  ));
  assert.ok(comparisons.some((comparison) =>
    comparison.question.includes('작품') && comparison.sameTopic
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
