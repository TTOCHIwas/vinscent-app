import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  extractWebhookRecordId,
  isRecord,
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';

type StorageCleanupRequest = {
  id: string;
  bucket_id: string;
  object_path: string;
  cleanup_reason: string;
  status: string;
};

Deno.serve(async (request) => {
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

  let requestId: string;
  try {
    requestId = extractWebhookRecordId(await request.json());
  } catch (error) {
    return jsonResponse(
      { error: 'invalid_payload', detail: String(error) },
      400,
    );
  }

  try {
    const supabase = createServiceRoleClient();
    const cleanupRequest = await loadStorageCleanupRequest(
      supabase,
      requestId,
    );

    if (!cleanupRequest) {
      return jsonResponse({
        status: 'skipped',
        error: 'storage_cleanup_request_missing',
      });
    }

    const claimedRequest = await claimStorageCleanupRequest(
      supabase,
      cleanupRequest.id,
    );

    if (!claimedRequest) {
      return jsonResponse({
        status: 'skipped',
        error: `storage_cleanup_request_${cleanupRequest.status}`,
      });
    }

    const { error } = await supabase.storage
      .from(claimedRequest.bucket_id)
      .remove([claimedRequest.object_path]);

    if (error) {
      await markStorageCleanupRequestFailed(
        supabase,
        claimedRequest.id,
        error.message,
      );
      return jsonResponse({
        status: 'failed',
        error: error.message,
      });
    }

    await markStorageCleanupRequestCompleted(supabase, claimedRequest.id);
    return jsonResponse({
      status: 'completed',
      bucketId: claimedRequest.bucket_id,
      objectPath: claimedRequest.object_path,
      cleanupReason: claimedRequest.cleanup_reason,
    });
  } catch (error) {
    return jsonResponse(
      { error: 'storage_cleanup_failed', detail: String(error) },
      500,
    );
  }
});

async function loadStorageCleanupRequest(
  supabase: ReturnType<typeof createServiceRoleClient>,
  requestId: string,
): Promise<StorageCleanupRequest | null> {
  const { data, error } = await supabase
    .from('storage_cleanup_requests')
    .select('id, bucket_id, object_path, cleanup_reason, status')
    .eq('id', requestId)
    .maybeSingle();

  if (error) {
    throw new Error(`storage_cleanup_request_query_failed:${error.message}`);
  }

  if (!isRecord(data)) {
    return null;
  }

  return data as StorageCleanupRequest;
}

async function claimStorageCleanupRequest(
  supabase: ReturnType<typeof createServiceRoleClient>,
  requestId: string,
): Promise<StorageCleanupRequest | null> {
  const { data, error } = await supabase
    .from('storage_cleanup_requests')
    .update({
      status: 'processing',
      last_error: null,
    })
    .eq('id', requestId)
    .eq('status', 'pending')
    .select('id, bucket_id, object_path, cleanup_reason, status')
    .maybeSingle();

  if (error) {
    throw new Error(`storage_cleanup_request_claim_failed:${error.message}`);
  }

  if (!isRecord(data)) {
    return null;
  }

  return data as StorageCleanupRequest;
}

async function markStorageCleanupRequestCompleted(
  supabase: ReturnType<typeof createServiceRoleClient>,
  requestId: string,
) {
  const { error } = await supabase
    .from('storage_cleanup_requests')
    .update({
      status: 'completed',
      last_error: null,
      processed_at: new Date().toISOString(),
    })
    .eq('id', requestId);

  if (error) {
    throw new Error(`storage_cleanup_request_complete_failed:${error.message}`);
  }
}

async function markStorageCleanupRequestFailed(
  supabase: ReturnType<typeof createServiceRoleClient>,
  requestId: string,
  errorMessage: string,
) {
  const { error } = await supabase
    .from('storage_cleanup_requests')
    .update({
      status: 'failed',
      last_error: errorMessage,
      processed_at: new Date().toISOString(),
    })
    .eq('id', requestId);

  if (error) {
    throw new Error(`storage_cleanup_request_fail_failed:${error.message}`);
  }
}
