import {
  optionalEnv,
  optionalPositiveIntegerEnv,
  requiredEnv,
} from '../_shared/environment.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';
import { SafetyModerationAlertProcessor } from './process_safety_moderation_alerts.ts';
import { SupabaseSafetyModerationAlertRepository } from './safety_moderation_alert_repository.ts';
import { SafetyModerationWebhookDelivery } from './safety_moderation_webhook_delivery.ts';
import { createSafetyModerationWorkerHttpHandler } from './safety_moderation_worker_http_handler.ts';

const repository = new SupabaseSafetyModerationAlertRepository(
  createServiceRoleClient(),
);
const delivery = new SafetyModerationWebhookDelivery({
  endpoint: requiredEnv('SAFETY_MODERATION_WEBHOOK_URL'),
  bearerToken: optionalEnv('SAFETY_MODERATION_WEBHOOK_BEARER_TOKEN'),
});
const processor = new SafetyModerationAlertProcessor({
  repository,
  delivery,
  workerId: `edge-safety-${crypto.randomUUID()}`,
});
const handler = createSafetyModerationWorkerHttpHandler({
  processor,
  maximumBatchSize:
    optionalPositiveIntegerEnv('SAFETY_MODERATION_WORKER_MAX_BATCH_SIZE') ??
      20,
});

Deno.serve((request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'SAFETY_MODERATION_WORKER_SECRET',
      headerName: 'x-safety-moderation-worker-secret',
      fallbackEnvName: 'SCHEDULE_WEBHOOK_SECRET',
      fallbackHeaderName: 'x-schedule-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  return handler(request);
});
