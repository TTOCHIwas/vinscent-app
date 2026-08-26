import { writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import {
  areQuestionsAboutSameTopic,
} from '../src/domain/question-duplicate-detector.ts';
import {
  CloudflareWorkersAiQuestionSimilarityClient,
} from '../src/infrastructure/cloudflare-workers-ai-question-similarity-client.ts';
import {
  createQuestionSimilarityEvaluationScenarios,
} from './question-similarity-eval-cases.ts';
import {
  evaluateQuestionSimilarityPredictions,
  selectQuestionSimilarityThreshold,
} from './question-similarity-eval-metrics.ts';

const model = '@cf/baai/bge-m3';
const client = new CloudflareWorkersAiQuestionSimilarityClient({
  accountId: requireEnvironment('CLOUDFLARE_ACCOUNT_ID'),
  apiToken: requireEnvironment('CLOUDFLARE_WORKERS_AI_API_TOKEN'),
});
const cases = [];

for (const scenario of createQuestionSimilarityEvaluationScenarios()) {
  const scores = await client.score(
    scenario.candidate,
    scenario.comparisons.map(({ question }) => question),
  );
  for (let index = 0; index < scenario.comparisons.length; index += 1) {
    const comparison = scenario.comparisons[index];
    const score = scores[index];
    if (comparison === undefined || score === undefined) {
      throw new Error('question similarity evaluation result is incomplete');
    }
    cases.push({
      scenarioId: scenario.id,
      candidate: scenario.candidate,
      question: comparison.question,
      sameTopic: comparison.sameTopic,
      lexicalSameTopic: areQuestionsAboutSameTopic(
        scenario.candidate,
        comparison.question,
      ),
      score,
    });
  }
}

const threshold = selectQuestionSimilarityThreshold(cases);
const report = {
  generatedAt: new Date().toISOString(),
  model,
  pairCount: cases.length,
  sameTopicCount: cases.filter(({ sameTopic }) => sameTopic).length,
  distinctTopicCount: cases.filter(({ sameTopic }) => !sameTopic).length,
  recommendedThreshold: threshold,
  lexicalMetrics: evaluateQuestionSimilarityPredictions(
    cases.map(({ lexicalSameTopic, sameTopic }) => ({
      predictedSameTopic: lexicalSameTopic,
      sameTopic,
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
