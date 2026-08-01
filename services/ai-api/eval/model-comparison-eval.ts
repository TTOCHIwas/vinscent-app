import {
  StructuredLearningModel,
} from '../src/application/structured-learning-model.ts';
import {
  CloudflareWorkersAiStructuredGenerationClient,
} from '../src/infrastructure/cloudflare-workers-ai-structured-generation-client.ts';
import {
  GeminiStructuredGenerationClient,
} from '../src/infrastructure/gemini-structured-generation-client.ts';
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

const defaultCloudflareModels = [
  '@cf/qwen/qwen3-30b-a3b-fp8',
  '@cf/meta/llama-3.3-70b-instruct-fp8-fast',
];
const defaultGeminiModel = 'gemini-3.1-flash-lite';
const defaultGeminiCaseDelayMs = 4_200;
const maximumRuns = 3;

const cloudflareAccountId = requireEnvironment('CLOUDFLARE_ACCOUNT_ID');
const cloudflareApiToken = requireEnvironment(
  'CLOUDFLARE_WORKERS_AI_API_TOKEN',
);
const geminiApiKey = requireEnvironment('GEMINI_API_KEY');
const geminiEndpoint = readOptionalEnvironment(
  'GEMINI_GENERATE_CONTENT_ENDPOINT',
);
const geminiCaseDelayMs = readNonNegativeInteger(
  'GEMINI_EVAL_CASE_DELAY_MS',
  defaultGeminiCaseDelayMs,
);
const modelSpecs: EvaluationModelSpec[] = [
  ...readList(
    'CLOUDFLARE_WORKERS_AI_EVAL_MODELS',
    defaultCloudflareModels,
  ).map<EvaluationModelSpec>((modelName) => ({
    provider: 'cloudflare',
    model: modelName,
    createModel: () => new StructuredLearningModel(
      new CloudflareWorkersAiStructuredGenerationClient({
        accountId: cloudflareAccountId,
        apiToken: cloudflareApiToken,
        model: modelName,
      }),
    ),
  })),
  ...readList(
    'GEMINI_EVAL_MODELS',
    [readOptionalEnvironment('GEMINI_MODEL') ?? defaultGeminiModel],
  ).map<EvaluationModelSpec>((modelName) => ({
    provider: 'google',
    model: modelName,
    caseDelayMs: geminiCaseDelayMs,
    createModel: () => new StructuredLearningModel(
      new GeminiStructuredGenerationClient({
        apiKey: geminiApiKey,
        model: modelName,
        ...(geminiEndpoint === null ? {} : { endpoint: geminiEndpoint }),
      }),
    ),
  })),
];

const execution = await runModelEvaluation({
  models: modelSpecs,
  cases: createModelEvaluationCases(),
  runs: readRuns(),
});
const outputPath = readOptionalEnvironment('AI_MODEL_EVAL_OUTPUT');
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

function readList(name: string, defaults: string[]): string[] {
  const configured = readOptionalEnvironment(name);
  const values = configured === null
    ? defaults
    : configured.split(',').map((value) => value.trim());
  const unique = [...new Set(values.filter((value) => value.length > 0))];
  if (unique.length === 0) {
    throw new Error(`${name} must contain at least one model`);
  }
  return unique;
}

function readRuns(): number {
  const raw = readOptionalEnvironment('AI_MODEL_EVAL_RUNS') ?? '1';
  const value = Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > maximumRuns) {
    throw new Error(
      `AI_MODEL_EVAL_RUNS must be between 1 and ${maximumRuns}`,
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
