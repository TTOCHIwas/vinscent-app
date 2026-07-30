import {
  optionalPositiveIntegerEnv,
  requiredEnv,
} from '../_shared/environment.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';
import { DiscordStorageCleanupAlertDelivery } from './discord_storage_cleanup_alert_delivery.ts';
import { createStorageCleanupAlertHttpHandler } from './storage_cleanup_alert_http_handler.ts';
import { StorageCleanupAlertProcessor } from './storage_cleanup_alert_processor.ts';
import { SupabaseStorageCleanupAlertRepository } from './storage_cleanup_alert_repository.ts';

const repository = new SupabaseStorageCleanupAlertRepository(
  createServiceRoleClient(),
);
const delivery = new DiscordStorageCleanupAlertDelivery({
  endpoint: requiredEnv('OPERATIONS_DISCORD_WEBHOOK_URL'),
});
const processor = new StorageCleanupAlertProcessor({
  repository,
  delivery,
  workerId: `edge-storage-alert-${crypto.randomUUID()}`,
});
const handler = createStorageCleanupAlertHttpHandler({
  processor,
  maximumBatchSize:
    optionalPositiveIntegerEnv(
      'STORAGE_CLEANUP_ALERT_WORKER_MAX_BATCH_SIZE',
    ) ?? 20,
});

Deno.serve((request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'STORAGE_CLEANUP_ALERT_WORKER_SECRET',
      headerName: 'x-storage-cleanup-alert-worker-secret',
      fallbackEnvName: 'SCHEDULE_WEBHOOK_SECRET',
      fallbackHeaderName: 'x-schedule-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  return handler(request);
});
