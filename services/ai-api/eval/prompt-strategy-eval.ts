import {
  StructuredLearningModel,
  type StructuredLearningPromptStrategy,
} from '../src/application/structured-learning-model.ts';
import {
  CloudflareWorkersAiStructuredGenerationClient,
} from '../src/infrastructure/cloudflare-workers-ai-structured-generation-client.ts';
import {
  serializeEvaluationReport,
  writeEvaluationReport,
} from './cloudflare-evaluation-report.ts';
import {
  createModelEvaluationCases,
} from './cloudflare-model-eval-cases.ts';
import {
  runModelEvaluation,
  type EvaluationModelSpec,
} from './model-evaluation-runner.ts';

const defaultModel = '@cf/mistralai/mistral-small-3.1-24b-instruct';
const defaultCaseDelayMs = 1_500;
const maximumRuns = 3;
const promptStrategies = [
  'legacy_korean',
  'refined_korean',
  'structured_korean',
  'hybrid_english_korean',
] as const satisfies readonly StructuredLearningPromptStrategy[];
const defaultPromptStrategies = [
  'legacy_korean',
  'refined_korean',
] as const satisfies readonly StructuredLearningPromptStrategy[];

const accountId = requireEnvironment('CLOUDFLARE_ACCOUNT_ID');
const apiToken = requireEnvironment('CLOUDFLARE_WORKERS_AI_API_TOKEN');
const modelName = readOptionalEnvironment('AI_PROMPT_EVAL_MODEL')
  ?? defaultModel;
const caseDelayMs = readNonNegativeInteger(
  'AI_PROMPT_EVAL_CASE_DELAY_MS',
  defaultCaseDelayMs,
);
const strategies = readPromptStrategies();
const modelSpecs = strategies.map<EvaluationModelSpec>((promptStrategy) => ({
  provider: 'cloudflare',
  model: modelName,
  caseDelayMs,
  configuration: { promptStrategy },
  createModel: () => new StructuredLearningModel(
    new CloudflareWorkersAiStructuredGenerationClient({
      accountId,
      apiToken,
      model: modelName,
    }),
    { promptStrategy },
  ),
}));
const cases = createModelEvaluationCases().filter(({ task }) =>
  task === 'couple_feedback' || task === 'personalized_question'
);

const execution = await runModelEvaluation({
  models: modelSpecs,
  cases,
  runs: readRuns(),
});
const outputPath = readOptionalEnvironment('AI_PROMPT_EVAL_OUTPUT');
if (outputPath !== null) {
  await writeEvaluationReport(outputPath, execution.report);
}
process.stdout.write(serializeEvaluationReport(execution.report));

if (execution.hasFailure) {
  process.exitCode = 1;
}

function requireEnvironment(name: string): string {
  const value = readOptionalEnvironment(name);
  if (value === null) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function readOptionalEnvironment(name: string): string | null {
  const value = process.env[name]?.trim();
  return value === undefined || value.length === 0 ? null : value;
}

function readPromptStrategies(): StructuredLearningPromptStrategy[] {
  const configured = readOptionalEnvironment('AI_PROMPT_EVAL_STRATEGIES');
  const values = configured === null
    ? [...defaultPromptStrategies]
    : configured.split(',').map((value) => value.trim());
  const unique = [...new Set(values)];
  if (unique.length === 0) {
    throw new Error('AI_PROMPT_EVAL_STRATEGIES must contain a strategy');
  }
  for (const value of unique) {
    if (!promptStrategies.includes(value as StructuredLearningPromptStrategy)) {
      throw new Error(`Unknown prompt strategy: ${value}`);
    }
  }
  return unique as StructuredLearningPromptStrategy[];
}

function readRuns(): number {
  const raw = readOptionalEnvironment('AI_PROMPT_EVAL_RUNS') ?? '1';
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > maximumRuns) {
    throw new Error(
      `AI_PROMPT_EVAL_RUNS must be between 1 and ${maximumRuns}`,
    );
  }
  return value;
}

function readNonNegativeInteger(name: string, fallback: number): number {
  const raw = readOptionalEnvironment(name);
  const value = raw === null ? fallback : Number(raw);
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`${name} must be a non-negative integer`);
  }
  return value;
}
