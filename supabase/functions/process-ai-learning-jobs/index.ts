import { LearningJobProcessor } from '../../../services/ai-api/src/application/process-learning-jobs.ts';
import { SupabaseLearningJobRepository } from '../../../services/ai-api/src/infrastructure/supabase-learning-job-repository.ts';
import { createLearningWorkerHttpHandler } from '../../../services/ai-api/src/presentation/learning-worker-http-handler.ts';
import { logLearningJobDiagnostic } from '../../../services/ai-api/src/presentation/learning-job-diagnostic-logger.ts';
import { createAiLearningModel } from '../_shared/ai_learning_model.ts';
import {
  optionalEnv,
  optionalPositiveIntegerEnv,
  requiredEnv,
} from '../_shared/environment.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';

const supabase = createServiceRoleClient();
const repository = new SupabaseLearningJobRepository(supabase);
const aiRuntime = createAiLearningModel({
  timeoutMs: optionalPositiveIntegerEnv(
    'CLOUDFLARE_WORKERS_AI_TIMEOUT_MS',
  ),
});
const processor = new LearningJobProcessor({
  repository,
  model: aiRuntime.model,
  workerId: `edge-${crypto.randomUUID()}`,
  provider: aiRuntime.provider,
  modelName: aiRuntime.modelName,
  onDiagnostic: logLearningJobDiagnostic,
});

Deno.serve(createLearningWorkerHttpHandler({
  serviceRoleKey: requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
  workerSecret: optionalEnv('AI_WORKER_SECRET')
    ?? optionalEnv('SCHEDULE_WEBHOOK_SECRET'),
  maximumBatchSize: optionalPositiveIntegerEnv('AI_WORKER_MAX_BATCH_SIZE') ?? 3,
  processor,
}));
