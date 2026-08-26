import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import {
  areQuestionsAboutSameTopic,
  buildQuestionSemanticFocus,
} from '../src/domain/question-duplicate-detector.ts';
import {
  CloudflareWorkersAiQuestionSimilarityClient,
} from '../src/infrastructure/cloudflare-workers-ai-question-similarity-client.ts';
import {
  createQuestionSimilarityEvaluationScenarios,
} from './question-similarity-eval-cases.ts';
import {
  evaluateHybridQuestionSimilarityLeaveOneGroupOut,
  evaluateQuestionSimilarityPredictions,
  evaluateQuestionSimilarityLeaveOneGroupOutAtPrecision,
  selectHybridQuestionSimilarityThresholdAtPrecision,
  selectQuestionSimilarityThreshold,
  selectQuestionSimilarityThresholdAtPrecision,
} from './question-similarity-eval-metrics.ts';

const model = '@cf/baai/bge-m3';
const minimumPrecision = 0.95;
const client = new CloudflareWorkersAiQuestionSimilarityClient({
  accountId: requireEnvironment('CLOUDFLARE_ACCOUNT_ID'),
  apiToken: requireEnvironment('CLOUDFLARE_WORKERS_AI_API_TOKEN'),
});
const cases = [];

for (const scenario of createQuestionSimilarityEvaluationScenarios()) {
  const rawScores = await client.score(
    scenario.candidate,
    scenario.comparisons.map(({ question }) => question),
  );
  const candidateFocus = buildQuestionSemanticFocus(scenario.candidate);
  const comparisonFocuses = scenario.comparisons.map(({ question }) =>
    buildQuestionSemanticFocus(question)
  );
  const focusScores = await client.score(candidateFocus, comparisonFocuses);
  for (let index = 0; index < scenario.comparisons.length; index += 1) {
    const comparison = scenario.comparisons[index];
    const rawScore = rawScores[index];
    const focusScore = focusScores[index];
    const comparisonFocus = comparisonFocuses[index];
    if (
      comparison === undefined
      || rawScore === undefined
      || focusScore === undefined
      || comparisonFocus === undefined
    ) {
      throw new Error('question similarity evaluation result is incomplete');
    }
    cases.push({
      scenarioId: scenario.id,
      candidate: scenario.candidate,
      candidateFocus,
      question: comparison.question,
      questionFocus: comparisonFocus,
      relation: comparison.relation,
      lexicalSameTopic: areQuestionsAboutSameTopic(
        scenario.candidate,
        comparison.question,
      ),
      score: rawScore,
      rawScore,
      focusScore,
    });
  }
}

const scoreEvaluations = {
  raw: evaluateScores(cases, ({ rawScore }) => rawScore),
  semanticFocus: evaluateScores(cases, ({ focusScore }) => focusScore),
};
const topicCooldownPairs = cases.map((item) => ({
  groupId: item.scenarioId,
  rawScore: item.rawScore,
  focusScore: item.focusScore,
  lexicalSameTopic: item.lexicalSameTopic,
  sameTopic: item.relation !== 'distinct',
}));
const topicCooldownValidation = {
  hybridPrecisionFirst: selectHybridQuestionSimilarityThresholdAtPrecision(
    topicCooldownPairs,
    minimumPrecision,
  ),
  leaveOneScenarioOut: {
    raw: evaluateQuestionSimilarityLeaveOneGroupOutAtPrecision(
      topicCooldownPairs.map((item) => ({
        groupId: item.groupId,
        score: item.rawScore,
        sameTopic: item.sameTopic,
      })),
      minimumPrecision,
    ),
    semanticFocus: evaluateQuestionSimilarityLeaveOneGroupOutAtPrecision(
      topicCooldownPairs.map((item) => ({
        groupId: item.groupId,
        score: item.focusScore,
        sameTopic: item.sameTopic,
      })),
      minimumPrecision,
    ),
    hybrid: evaluateHybridQuestionSimilarityLeaveOneGroupOut(
      topicCooldownPairs,
      minimumPrecision,
    ),
  },
};
const report = {
  generatedAt: new Date().toISOString(),
  model,
  pairCount: cases.length,
  nearDuplicateCount: cases.filter(
    ({ relation }) => relation === 'near_duplicate'
  ).length,
  topicOverlapCount: cases.filter(
    ({ relation }) => relation === 'topic_overlap'
  ).length,
  distinctTopicCount: cases.filter(
    ({ relation }) => relation === 'distinct'
  ).length,
  recommendedThreshold: scoreEvaluations.raw.topicCooldown.f1Optimal,
  scoreEvaluations,
  topicCooldownValidation,
  lexicalStrictDuplicateMetrics: evaluateQuestionSimilarityPredictions(
    cases.map(({ lexicalSameTopic, relation }) => ({
      predictedSameTopic: lexicalSameTopic,
      sameTopic: relation === 'near_duplicate',
    })),
  ),
  lexicalTopicCooldownMetrics: evaluateQuestionSimilarityPredictions(
    cases.map(({ lexicalSameTopic, relation }) => ({
      predictedSameTopic: lexicalSameTopic,
      sameTopic: relation !== 'distinct',
    })),
  ),
  cases,
};
const serialized = `${JSON.stringify(report, null, 2)}\n`;
const outputPath = optionalEnvironment('QUESTION_SIMILARITY_EVAL_OUTPUT');
if (outputPath !== null) {
  await writeFile(resolve(outputPath), serialized, 'utf8');
}
process.stdout.write(serialized);

function evaluateScores<T extends {
  relation: 'near_duplicate' | 'topic_overlap' | 'distinct';
}>(
  evaluationCases: readonly T[],
  readScore: (item: T) => number,
) {
  return {
    strictDuplicate: evaluateThresholdTask(
      evaluationCases,
      readScore,
      ({ relation }) => relation === 'near_duplicate',
    ),
    topicCooldown: evaluateThresholdTask(
      evaluationCases,
      readScore,
      ({ relation }) => relation !== 'distinct',
    ),
  };
}

function evaluateThresholdTask<T>(
  evaluationCases: readonly T[],
  readScore: (item: T) => number,
  isPositive: (item: T) => boolean,
) {
  const pairs = evaluationCases.map((item) => ({
    score: readScore(item),
    sameTopic: isPositive(item),
  }));
  return {
    f1Optimal: selectQuestionSimilarityThreshold(pairs),
    precisionFirst: selectQuestionSimilarityThresholdAtPrecision(
      pairs,
      minimumPrecision,
    ),
  };
}

function requireEnvironment(name: string): string {
  const value = optionalEnvironment(name);
  if (value === null) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function optionalEnvironment(name: string): string | null {
  const value = process.env[name]?.trim();
  return value === undefined || value.length === 0 ? null : value;
}
