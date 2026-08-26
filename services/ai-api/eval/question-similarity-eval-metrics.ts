export interface ScoredQuestionSimilarityPair {
  score: number;
  sameTopic: boolean;
}

export interface QuestionSimilarityMetrics {
  truePositive: number;
  falsePositive: number;
  trueNegative: number;
  falseNegative: number;
  precision: number;
  recall: number;
  f1: number;
  accuracy: number;
}

export interface QuestionSimilarityThresholdResult {
  threshold: number;
  metrics: QuestionSimilarityMetrics;
}

export function selectQuestionSimilarityThreshold(
  pairs: readonly ScoredQuestionSimilarityPair[],
): QuestionSimilarityThresholdResult {
  if (pairs.length === 0) {
    throw new RangeError('question similarity pairs are required');
  }
  for (const pair of pairs) {
    if (!Number.isFinite(pair.score)) {
      throw new TypeError('question similarity score must be finite');
    }
  }

  const candidates = [...new Set(pairs.map(({ score }) => score))]
    .sort((left, right) => right - left);
  const results = candidates.map((threshold) => ({
    threshold,
    metrics: evaluateQuestionSimilarityPredictions(
      pairs.map((pair) => ({
        predictedSameTopic: pair.score >= threshold,
        sameTopic: pair.sameTopic,
      })),
    ),
  }));
  results.sort(compareThresholdResults);
  return results[0] as QuestionSimilarityThresholdResult;
}

export function evaluateQuestionSimilarityPredictions(
  pairs: ReadonlyArray<{
    predictedSameTopic: boolean;
    sameTopic: boolean;
  }>,
): QuestionSimilarityMetrics {
  if (pairs.length === 0) {
    throw new RangeError('question similarity predictions are required');
  }
  let truePositive = 0;
  let falsePositive = 0;
  let trueNegative = 0;
  let falseNegative = 0;

  for (const pair of pairs) {
    if (pair.predictedSameTopic && pair.sameTopic) {
      truePositive += 1;
    } else if (pair.predictedSameTopic) {
      falsePositive += 1;
    } else if (pair.sameTopic) {
      falseNegative += 1;
    } else {
      trueNegative += 1;
    }
  }

  const precision = divide(truePositive, truePositive + falsePositive);
  const recall = divide(truePositive, truePositive + falseNegative);
  return {
    truePositive,
    falsePositive,
    trueNegative,
    falseNegative,
    precision,
    recall,
    f1: precision + recall === 0
      ? 0
      : (2 * precision * recall) / (precision + recall),
    accuracy: (truePositive + trueNegative) / pairs.length,
  };
}

function compareThresholdResults(
  left: QuestionSimilarityThresholdResult,
  right: QuestionSimilarityThresholdResult,
): number {
  return right.metrics.f1 - left.metrics.f1
    || right.metrics.precision - left.metrics.precision
    || right.metrics.recall - left.metrics.recall
    || right.metrics.accuracy - left.metrics.accuracy
    || right.threshold - left.threshold;
}

function divide(numerator: number, denominator: number): number {
  return denominator === 0 ? 0 : numerator / denominator;
}
