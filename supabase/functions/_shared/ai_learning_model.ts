import {
  StructuredLearningModel,
} from '../../../services/ai-api/src/application/structured-learning-model.ts';
import {
  CloudflareWorkersAiStructuredGenerationClient,
} from '../../../services/ai-api/src/infrastructure/cloudflare-workers-ai-structured-generation-client.ts';
import {
  optionalEnv,
  readDenoEnvironment,
  requiredEnv,
  type EnvironmentReader,
} from './environment.ts';

export const defaultAiModelName =
  '@cf/mistralai/mistral-small-3.1-24b-instruct';

interface CreateAiLearningModelOptions {
  readEnvironment?: EnvironmentReader;
  timeoutMs?: number;
}

export function createAiLearningModel(
  options: CreateAiLearningModelOptions = {},
) {
  const readEnvironment = options.readEnvironment ?? readDenoEnvironment;
  const modelName = optionalEnv(
    'CLOUDFLARE_WORKERS_AI_MODEL',
    readEnvironment,
  ) ?? defaultAiModelName;
  const client = new CloudflareWorkersAiStructuredGenerationClient({
    accountId: requiredEnv('CLOUDFLARE_ACCOUNT_ID', readEnvironment),
    apiToken: requiredEnv(
      'CLOUDFLARE_WORKERS_AI_API_TOKEN',
      readEnvironment,
    ),
    model: modelName,
    timeoutMs: options.timeoutMs,
  });

  return {
    model: new StructuredLearningModel(client),
    provider: 'cloudflare' as const,
    modelName,
  };
}
