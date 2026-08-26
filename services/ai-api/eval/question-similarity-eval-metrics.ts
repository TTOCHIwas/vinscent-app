export interface ScoredQuestionSimilarityPair {
  score: number;
  sameTopic: boolean;
}

export interface GroupedScoredQuestionSimilarityPair
  extends ScoredQuestionSimilarityPair {
  groupId: string;
}

export interface HybridQuestionSimilarityPair {
  rawScore: number;
  focusScore: number;
  lexicalSameTopic: boolean;
  sameTopic: boolean;
}

export interface GroupedHybridQuestionSimilarityPair
  extends HybridQuestionSimilarityPair {
  groupId: string;
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

export interface HybridQuestionSimilarityThresholdResult {
  rawThreshold: number | null;
  focusThreshold: number | null;
  metrics: QuestionSimilarityMetrics;
}

export interface QuestionSimilarityLeaveOneGroupOutResult {
  metrics: QuestionSimilarityMetrics;
  folds: Array<{
    groupId: string;
    threshold: number | null;
    trainingMetrics: QuestionSimilarityMetrics | null;
    holdoutMetrics: QuestionSimilarityMetrics;
  }>;
}

export interface HybridQuestionSimilarityLeaveOneGroupOutResult {
  metrics: QuestionSimilarityMetrics;
  folds: Array<{
    groupId: string;
    rawThreshold: number | null;
    focusThreshold: number | null;
    trainingMetrics: QuestionSimilarityMetrics | null;
    holdoutMetrics: QuestionSimilarityMetrics;
  }>;
}

export function selectQuestionSimilarityThreshold(
  pairs: readonly ScoredQuestionSimilarityPair[],
): QuestionSimilarityThresholdResult {
  const results = evaluateQuestionSimilarityThresholds(pairs);
  results.sort(compareThresholdResults);
  return results[0] as QuestionSimilarityThresholdResult;
}

export function selectQuestionSimilarityThresholdAtPrecision(
  pairs: readonly ScoredQuestionSimilarityPair[],
  minimumPrecision: number,
): QuestionSimilarityThresholdResult | null {
  validateMinimumPrecision(minimumPrecision);
  const results = evaluateQuestionSimilarityThresholds(pairs)
    .filter(({ metrics }) =>
      metrics.truePositive > 0 && metrics.precision >= minimumPrecision
    );
  results.sort(comparePrecisionFirstThresholdResults);
  return results[0] ?? null;
}

export function selectHybridQuestionSimilarityThresholdAtPrecision(
  pairs: readonly HybridQuestionSimilarityPair[],
  minimumPrecision: number,
): HybridQuestionSimilarityThresholdResult | null {
  validateMinimumPrecision(minimumPrecision);
  validateHybridQuestionSimilarityPairs(pairs);

  const rawThresholds = uniqueThresholdsWithDisabled(
    pairs.map(({ rawScore }) => rawScore),
  );
  const focusThresholds = uniqueThresholdsWithDisabled(
    pairs.map(({ focusScore }) => focusScore),
  );
  const results: HybridQuestionSimilarityThresholdResult[] = [];

  for (const rawThreshold of rawThresholds) {
    for (const focusThreshold of focusThresholds) {
      const metrics = evaluateQuestionSimilarityPredictions(
        pairs.map((pair) => ({
          predictedSameTopic: isHybridQuestionSimilarityMatch(
            pair,
            rawThreshold,
            focusThreshold,
          ),
          sameTopic: pair.sameTopic,
        })),
      );
      if (
        metrics.truePositive > 0
        && metrics.precision >= minimumPrecision
      ) {
        results.push({ rawThreshold, focusThreshold, metrics });
      }
    }
  }

  results.sort(compareHybridPrecisionFirstThresholdResults);
  return results[0] ?? null;
}

export function evaluateQuestionSimilarityLeaveOneGroupOutAtPrecision(
  pairs: readonly GroupedScoredQuestionSimilarityPair[],
  minimumPrecision: number,
): QuestionSimilarityLeaveOneGroupOutResult {
  validateMinimumPrecision(minimumPrecision);
  const groupIds = requireMultipleQuestionSimilarityGroups(pairs);
  const predictions: Array<{
    predictedSameTopic: boolean;
    sameTopic: boolean;
  }> = [];
  const folds = groupIds.map((groupId) => {
    const training = pairs.filter((pair) => pair.groupId !== groupId);
    const holdout = pairs.filter((pair) => pair.groupId === groupId);
    const selected = selectQuestionSimilarityThresholdAtPrecision(
      training,
      minimumPrecision,
    );
    const holdoutPredictions = holdout.map((pair) => ({
      predictedSameTopic: selected !== null
        && pair.score >= selected.threshold,
      sameTopic: pair.sameTopic,
    }));
    predictions.push(...holdoutPredictions);
    return {
      groupId,
      threshold: selected?.threshold ?? null,
      trainingMetrics: selected?.metrics ?? null,
      holdoutMetrics: evaluateQuestionSimilarityPredictions(
        holdoutPredictions,
      ),
    };
  });

  return {
    metrics: evaluateQuestionSimilarityPredictions(predictions),
    folds,
  };
}

export function evaluateHybridQuestionSimilarityLeaveOneGroupOut(
  pairs: readonly GroupedHybridQuestionSimilarityPair[],
  minimumPrecision: number,
): HybridQuestionSimilarityLeaveOneGroupOutResult {
  validateMinimumPrecision(minimumPrecision);
  validateHybridQuestionSimilarityPairs(pairs);
  const groupIds = requireMultipleQuestionSimilarityGroups(pairs);
  const predictions: Array<{
    predictedSameTopic: boolean;
    sameTopic: boolean;
  }> = [];
  const folds = groupIds.map((groupId) => {
    const training = pairs.filter((pair) => pair.groupId !== groupId);
    const holdout = pairs.filter((pair) => pair.groupId === groupId);
    const selected = selectHybridQuestionSimilarityThresholdAtPrecision(
      training,
      minimumPrecision,
    );
    const holdoutPredictions = holdout.map((pair) => ({
      predictedSameTopic: selected !== null
        && isHybridQuestionSimilarityMatch(
          pair,
          selected.rawThreshold,
          selected.focusThreshold,
        ),
      sameTopic: pair.sameTopic,
    }));
    predictions.push(...holdoutPredictions);
    return {
      groupId,
      rawThreshold: selected?.rawThreshold ?? null,
      focusThreshold: selected?.focusThreshold ?? null,
      trainingMetrics: selected?.metrics ?? null,
      holdoutMetrics: evaluateQuestionSimilarityPredictions(
        holdoutPredictions,
      ),
    };
  });

  return {
    metrics: evaluateQuestionSimilarityPredictions(predictions),
    folds,
  };
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

function comparePrecisionFirstThresholdResults(
  left: QuestionSimilarityThresholdResult,
  right: QuestionSimilarityThresholdResult,
): number {
  return right.metrics.recall - left.metrics.recall
    || right.metrics.precision - left.metrics.precision
    || right.metrics.f1 - left.metrics.f1
    || right.metrics.accuracy - left.metrics.accuracy
    || right.threshold - left.threshold;
}

function compareHybridPrecisionFirstThresholdResults(
  left: HybridQuestionSimilarityThresholdResult,
  right: HybridQuestionSimilarityThresholdResult,
): number {
  return right.metrics.recall - left.metrics.recall
    || right.metrics.precision - left.metrics.precision
    || right.metrics.f1 - left.metrics.f1
    || right.metrics.accuracy - left.metrics.accuracy
    || enabledThresholdCount(left) - enabledThresholdCount(right)
    || compareNullableThresholds(left.rawThreshold, right.rawThreshold)
    || compareNullableThresholds(left.focusThreshold, right.focusThreshold);
}

function evaluateQuestionSimilarityThresholds(
  pairs: readonly ScoredQuestionSimilarityPair[],
): QuestionSimilarityThresholdResult[] {
  if (pairs.length === 0) {
    throw new RangeError('question similarity pairs are required');
  }
  for (const pair of pairs) {
    if (!Number.isFinite(pair.score)) {
      throw new TypeError('question similarity score must be finite');
    }
  }

  return [...new Set(pairs.map(({ score }) => score))]
    .sort((left, right) => right - left)
    .map((threshold) => ({
      threshold,
      metrics: evaluateQuestionSimilarityPredictions(
        pairs.map((pair) => ({
          predictedSameTopic: pair.score >= threshold,
          sameTopic: pair.sameTopic,
        })),
      ),
    }));
}

function validateHybridQuestionSimilarityPairs(
  pairs: readonly HybridQuestionSimilarityPair[],
): void {
  if (pairs.length === 0) {
    throw new RangeError('hybrid question similarity pairs are required');
  }
  for (const pair of pairs) {
    if (
      !Number.isFinite(pair.rawScore)
      || !Number.isFinite(pair.focusScore)
    ) {
      throw new TypeError('hybrid question similarity scores must be finite');
    }
  }
}

function requireMultipleQuestionSimilarityGroups(
  pairs: readonly { groupId: string }[],
): string[] {
  const groupIds = [...new Set(pairs.map(({ groupId }) => groupId))];
  if (groupIds.length < 2 || groupIds.some((groupId) => groupId.length === 0)) {
    throw new RangeError(
      'leave-one-group-out evaluation requires at least two groups',
    );
  }
  return groupIds;
}

function uniqueThresholdsWithDisabled(
  scores: readonly number[],
): Array<number | null> {
  return [
    null,
    ...[...new Set(scores)].sort((left, right) => right - left),
  ];
}

function isHybridQuestionSimilarityMatch(
  pair: HybridQuestionSimilarityPair,
  rawThreshold: number | null,
  focusThreshold: number | null,
): boolean {
  return pair.lexicalSameTopic
    || (rawThreshold !== null && pair.rawScore >= rawThreshold)
    || (focusThreshold !== null && pair.focusScore >= focusThreshold);
}

function enabledThresholdCount(
  result: Pick<
    HybridQuestionSimilarityThresholdResult,
    'rawThreshold' | 'focusThreshold'
  >,
): number {
  return Number(result.rawThreshold !== null)
    + Number(result.focusThreshold !== null);
}

function compareNullableThresholds(
  left: number | null,
  right: number | null,
): number {
  if (left === null) {
    return right === null ? 0 : -1;
  }
  if (right === null) {
    return 1;
  }
  return right - left;
}

function validateMinimumPrecision(minimumPrecision: number): void {
  if (
    !Number.isFinite(minimumPrecision)
    || minimumPrecision < 0
    || minimumPrecision > 1
  ) {
    throw new RangeError('minimum question similarity precision is invalid');
  }
}

function divide(numerator: number, denominator: number): number {
  return denominator === 0 ? 0 : numerator / denominator;
}
