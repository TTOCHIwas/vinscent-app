import {
  StructuredLearningModel,
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

const defaultModels = [
  '@cf/qwen/qwen3-30b-a3b-fp8',
];
const maximumRuns = 3;

const accountId = requireEnvironment('CLOUDFLARE_ACCOUNT_ID');
const apiToken = requireEnvironment('CLOUDFLARE_WORKERS_AI_API_TOKEN');
const models = readModels().map<EvaluationModelSpec>((modelName) => ({
  provider: 'cloudflare',
  model: modelName,
  createModel: () => new StructuredLearningModel(
    new CloudflareWorkersAiStructuredGenerationClient({
      accountId,
      apiToken,
      model: modelName,
    }),
  ),
}));
const execution = await runModelEvaluation({
  models,
  cases: createModelEvaluationCases(),
  runs: readRuns(),
});
const outputPath = readOptionalEnvironment(
  'CLOUDFLARE_WORKERS_AI_EVAL_OUTPUT',
);
if (outputPath !== null) {
  await writeEvaluationReport(outputPath, execution.report);
}
process.stdout.write(serializeEvaluationReport(execution.report));

if (execution.hasFailure) {
  process.exitCode = 1;
}

function requireEnvironment(name: string): string {
  const value = process.env[name]?.trim();
  if (value === undefined || value.length === 0) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function readOptionalEnvironment(name: string): string | null {
  const value = process.env[name]?.trim();
  return value === undefined || value.length === 0 ? null : value;
}

function readModels(): string[] {
  const configured = process.env.CLOUDFLARE_WORKERS_AI_EVAL_MODELS;
  const values = configured === undefined
    ? defaultModels
    : configured.split(',').map((value) => value.trim());
  const unique = [...new Set(values.filter((value) => value.length > 0))];
  if (unique.length === 0) {
    throw new Error('At least one Cloudflare evaluation model is required');
  }
  return unique;
}

function readRuns(): number {
  const raw = process.env.CLOUDFLARE_WORKERS_AI_EVAL_RUNS?.trim() ?? '1';
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > maximumRuns) {
    throw new Error(
      `CLOUDFLARE_WORKERS_AI_EVAL_RUNS must be between 1 and ${maximumRuns}`,
    );
  }
  return value;
}
