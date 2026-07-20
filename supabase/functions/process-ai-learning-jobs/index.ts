import { LearningJobProcessor } from '../../../services/ai-api/src/application/process-learning-jobs.ts';
import { GeminiStructuredGenerationClient } from '../../../services/ai-api/src/infrastructure/gemini-structured-generation-client.ts';
import { GeminiLearningModel } from '../../../services/ai-api/src/infrastructure/gemini-learning-model.ts';
import { SupabaseLearningJobRepository } from '../../../services/ai-api/src/infrastructure/supabase-learning-job-repository.ts';
import { createLearningWorkerHttpHandler } from '../../../services/ai-api/src/presentation/learning-worker-http-handler.ts';
import {
  createServiceRoleClient,
  requiredEnv,
} from '../_shared/push.ts';

const defaultModel = 'gemini-3.1-flash-lite';

const modelName = optionalEnv('GEMINI_MODEL') ?? defaultModel;
const supabase = createServiceRoleClient();
const repository = new SupabaseLearningJobRepository(supabase);
const client = new GeminiStructuredGenerationClient({
  apiKey: requiredEnv('GEMINI_API_KEY'),
  model: modelName,
  endpoint: optionalEnv('GEMINI_GENERATE_CONTENT_ENDPOINT'),
  timeoutMs: optionalPositiveIntegerEnv('GEMINI_TIMEOUT_MS'),
});
const processor = new LearningJobProcessor({
  repository,
  model: new GeminiLearningModel(client),
  workerId: `edge-${crypto.randomUUID()}`,
  provider: 'google',
  modelName,
});

Deno.serve(createLearningWorkerHttpHandler({
  serviceRoleKey: requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
  workerSecret: optionalEnv('AI_WORKER_SECRET')
    ?? optionalEnv('SCHEDULE_WEBHOOK_SECRET'),
  maximumBatchSize: optionalPositiveIntegerEnv('AI_WORKER_MAX_BATCH_SIZE') ?? 1,
  processor,
}));

function optionalEnv(name: string): string | undefined {
  const value = Deno.env.get(name)?.trim();
  return value ? value : undefined;
}

function optionalPositiveIntegerEnv(name: string): number | undefined {
  const value = optionalEnv(name);
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new RangeError(`${name} must be a positive integer`);
  }
  return parsed;
}
