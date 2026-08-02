import {
  StructuredLearningModel,
} from '../src/application/structured-learning-model.ts';
import {
  CloudflareWorkersAiStructuredGenerationClient,
} from '../src/infrastructure/cloudflare-workers-ai-structured-generation-client.ts';
import {
  GroqStructuredGenerationClient,
  type GroqReasoningEffort,
} from '../src/infrastructure/groq-structured-generation-client.ts';
import {
  OpenAiResponsesStructuredGenerationClient,
  type OpenAiReasoningEffort,
} from '../src/infrastructure/openai-responses-structured-generation-client.ts';
import type {
  EvaluationModelSpec,
} from './model-evaluation-runner.ts';
import type {
  CandidateModelEvaluationSuite,
} from './candidate-model-eval-suite.ts';

const defaultCloudflareModels = [
  '@cf/qwen/qwen3-30b-a3b-fp8',
  '@cf/zai-org/glm-4.7-flash',
  '@cf/google/gemma-4-26b-a4b-it',
  '@cf/mistralai/mistral-small-3.1-24b-instruct',
];
const defaultGroqModels = [
  'openai/gpt-oss-120b',
  'openai/gpt-oss-20b',
];
const defaultOpenAiModels = [
  'gpt-5-nano',
];
const defaultGroqCaseDelayMs = 15_000;
const maximumRuns = 3;
const supportedProviders = new Set(['cloudflare', 'groq', 'openai']);

export interface CandidateModelEvaluationPlan {
  models: EvaluationModelSpec[];
  runs: number;
  suite: CandidateModelEvaluationSuite;
  outputPath: string | null;
}

export function createCandidateModelEvaluationPlan(
  environment: Readonly<Record<string, string | undefined>>,
): CandidateModelEvaluationPlan {
  const providers = readProviders(environment);
  const models: EvaluationModelSpec[] = [];

  if (providers.includes('cloudflare')) {
    models.push(...createCloudflareModelSpecs(environment));
  }
  if (providers.includes('groq')) {
    models.push(...createGroqModelSpecs(environment));
  }
  if (providers.includes('openai')) {
    models.push(...createOpenAiModelSpecs(environment));
  }

  return {
    models,
    runs: readBoundedPositiveInteger(
      environment,
      'AI_MODEL_EVAL_RUNS',
      1,
      maximumRuns,
    ),
    suite: readSuite(environment),
    outputPath: readOptionalEnvironment(
      environment,
      'AI_CANDIDATE_EVAL_OUTPUT',
    ),
  };
}

function readSuite(
  environment: Readonly<Record<string, string | undefined>>,
): CandidateModelEvaluationSuite {
  const value = readOptionalEnvironment(
    environment,
    'AI_CANDIDATE_EVAL_SUITE',
  ) ?? 'smoke';
  if (value === 'smoke' || value === 'full') {
    return value;
  }
  throw new Error('AI_CANDIDATE_EVAL_SUITE must be smoke or full');
}

function createCloudflareModelSpecs(
  environment: Readonly<Record<string, string | undefined>>,
): EvaluationModelSpec[] {
  const accountId = requireEnvironment(environment, 'CLOUDFLARE_ACCOUNT_ID');
  const apiToken = requireEnvironment(
    environment,
    'CLOUDFLARE_WORKERS_AI_API_TOKEN',
  );
  const caseDelayMs = readNonNegativeInteger(
    environment,
    'CLOUDFLARE_EVAL_CASE_DELAY_MS',
    0,
  );
  return readList(
    environment,
    'CLOUDFLARE_WORKERS_AI_EVAL_MODELS',
    defaultCloudflareModels,
  ).map((modelName) => ({
    provider: 'cloudflare',
    model: modelName,
    caseDelayMs,
    configuration: {
      structuredOutput: 'json_schema',
    },
    createModel: () => new StructuredLearningModel(
      new CloudflareWorkersAiStructuredGenerationClient({
        accountId,
        apiToken,
        model: modelName,
      }),
    ),
  }));
}

function createGroqModelSpecs(
  environment: Readonly<Record<string, string | undefined>>,
): EvaluationModelSpec[] {
  const apiKey = requireEnvironment(environment, 'GROQ_API_KEY');
  const endpoint = readOptionalEnvironment(
    environment,
    'GROQ_CHAT_COMPLETIONS_ENDPOINT',
  );
  const reasoningEffort = readGroqReasoningEffort(environment);
  const caseDelayMs = readNonNegativeInteger(
    environment,
    'GROQ_EVAL_CASE_DELAY_MS',
    defaultGroqCaseDelayMs,
  );
  return readList(
    environment,
    'GROQ_EVAL_MODELS',
    defaultGroqModels,
  ).map((modelName) => ({
    provider: 'groq',
    model: modelName,
    caseDelayMs,
    configuration: {
      reasoningEffort,
      structuredOutput: 'strict_json_schema',
    },
    createModel: () => new StructuredLearningModel(
      new GroqStructuredGenerationClient({
        apiKey,
        model: modelName,
        reasoningEffort,
        ...(endpoint === null ? {} : { endpoint }),
      }),
    ),
  }));
}

function createOpenAiModelSpecs(
  environment: Readonly<Record<string, string | undefined>>,
): EvaluationModelSpec[] {
  const apiKey = requireEnvironment(environment, 'OPENAI_API_KEY');
  const endpoint = readOptionalEnvironment(
    environment,
    'OPENAI_RESPONSES_ENDPOINT',
  );
  const configuredReasoningEffort = readOpenAiReasoningEffort(environment);
  const caseDelayMs = readNonNegativeInteger(
    environment,
    'OPENAI_EVAL_CASE_DELAY_MS',
    0,
  );
  return readList(
    environment,
    'OPENAI_EVAL_MODELS',
    defaultOpenAiModels,
  ).map((modelName) => {
    const reasoningEffort = configuredReasoningEffort
      ?? defaultOpenAiReasoningEffort(modelName);
    return {
      provider: 'openai',
      model: modelName,
      caseDelayMs,
      configuration: {
        reasoningEffort,
        structuredOutput: 'responses_json_schema',
      },
      createModel: () => new StructuredLearningModel(
        new OpenAiResponsesStructuredGenerationClient({
          apiKey,
          model: modelName,
          reasoningEffort,
          ...(endpoint === null ? {} : { endpoint }),
        }),
      ),
    };
  });
}

function readProviders(
  environment: Readonly<Record<string, string | undefined>>,
): string[] {
  const providers = readList(
    environment,
    'AI_CANDIDATE_EVAL_PROVIDERS',
    ['cloudflare', 'groq'],
  );
  for (const provider of providers) {
    if (!supportedProviders.has(provider)) {
      throw new Error(
        `AI_CANDIDATE_EVAL_PROVIDERS contains unsupported provider: ${provider}`,
      );
    }
  }
  return providers;
}

function readGroqReasoningEffort(
  environment: Readonly<Record<string, string | undefined>>,
): GroqReasoningEffort {
  const value = readOptionalEnvironment(
    environment,
    'GROQ_EVAL_REASONING_EFFORT',
  ) ?? 'low';
  if (value === 'low' || value === 'medium' || value === 'high') {
    return value;
  }
  throw new Error(
    'GROQ_EVAL_REASONING_EFFORT must be low, medium, or high',
  );
}

function readOpenAiReasoningEffort(
  environment: Readonly<Record<string, string | undefined>>,
): OpenAiReasoningEffort | null {
  const value = readOptionalEnvironment(
    environment,
    'OPENAI_EVAL_REASONING_EFFORT',
  );
  if (value === null) {
    return null;
  }
  if (
    value === 'none'
    || value === 'minimal'
    || value === 'low'
    || value === 'medium'
    || value === 'high'
    || value === 'xhigh'
    || value === 'max'
  ) {
    return value;
  }
  throw new Error(
    'OPENAI_EVAL_REASONING_EFFORT must be none, minimal, low, medium, high, xhigh, or max',
  );
}

function defaultOpenAiReasoningEffort(
  modelName: string,
): OpenAiReasoningEffort {
  const normalized = modelName.toLowerCase();
  const isGpt5Nano = normalized === 'gpt-5-nano'
    || normalized.startsWith('gpt-5-nano-');
  return isGpt5Nano ? 'minimal' : 'none';
}

function requireEnvironment(
  environment: Readonly<Record<string, string | undefined>>,
  name: string,
): string {
  const value = readOptionalEnvironment(environment, name);
  if (value === null) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function readOptionalEnvironment(
  environment: Readonly<Record<string, string | undefined>>,
  name: string,
): string | null {
  const value = environment[name]?.trim();
  return value === undefined || value.length === 0 ? null : value;
}

function readList(
  environment: Readonly<Record<string, string | undefined>>,
  name: string,
  defaults: string[],
): string[] {
  const configured = readOptionalEnvironment(environment, name);
  const values = configured === null
    ? defaults
    : configured.split(',').map((value) => value.trim());
  const unique = [...new Set(values.filter((value) => value.length > 0))];
  if (unique.length === 0) {
    throw new Error(`${name} must contain at least one value`);
  }
  return unique;
}

function readNonNegativeInteger(
  environment: Readonly<Record<string, string | undefined>>,
  name: string,
  fallback: number,
): number {
  const raw = readOptionalEnvironment(environment, name);
  const value = raw === null ? fallback : Number(raw);
  if (!Number.isInteger(value) || value < 0) {
    throw new Error(`${name} must be a non-negative integer`);
  }
  return value;
}

function readBoundedPositiveInteger(
  environment: Readonly<Record<string, string | undefined>>,
  name: string,
  fallback: number,
  maximum: number,
): number {
  const raw = readOptionalEnvironment(environment, name);
  const value = raw === null ? fallback : Number(raw);
  if (!Number.isInteger(value) || value < 1 || value > maximum) {
    throw new Error(`${name} must be between 1 and ${maximum}`);
  }
  return value;
}
