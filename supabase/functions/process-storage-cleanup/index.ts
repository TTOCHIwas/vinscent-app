import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';
import { StorageCleanupProcessor } from './storage_cleanup_processor.ts';
import { SupabaseStorageCleanupRepository } from './storage_cleanup_repository.ts';
import { createStorageCleanupHttpHandler } from './storage_cleanup_http_handler.ts';
import { SupabaseStorageObjectStore } from './supabase_storage_object_store.ts';

const supabase = createServiceRoleClient();
const processor = new StorageCleanupProcessor({
  repository: new SupabaseStorageCleanupRepository(supabase),
  objectStore: new SupabaseStorageObjectStore(supabase),
  workerId: `edge-storage-${crypto.randomUUID()}`,
});
const handler = createStorageCleanupHttpHandler({ processor });

Deno.serve((request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'STORAGE_CLEANUP_WEBHOOK_SECRET',
      headerName: 'x-storage-cleanup-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  return handler(request);
});
