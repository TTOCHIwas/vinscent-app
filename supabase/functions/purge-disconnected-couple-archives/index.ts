import { createServiceRoleClient } from '../_shared/supabase.ts';
import {
  internalErrorResponse,
  invalidPayloadResponse,
  isRecord,
  jsonResponse,
  verifyWebhookSecret,
} from '../_shared/webhook.ts';

const defaultBatchLimit = 50;

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405);
  }

  if (
    !verifyWebhookSecret(request, {
      envName: 'ARCHIVE_PURGE_WEBHOOK_SECRET',
      headerName: 'x-archive-purge-webhook-secret',
      fallbackEnvName: 'SCHEDULE_WEBHOOK_SECRET',
      fallbackHeaderName: 'x-schedule-webhook-secret',
    })
  ) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await parseRequestBody(request);
  } catch {
    return invalidPayloadResponse();
  }
  const batchLimit = normalizeBatchLimit(body.batch_limit);

  try {
    const supabase = createServiceRoleClient();
    const { data, error } = await supabase.rpc(
      'purge_expired_disconnected_couples',
      {
        batch_limit: batchLimit,
      },
    );

    if (error) {
      throw new Error(`archive_purge_failed:${error.message}`);
    }

    return jsonResponse({
      status: 'ok',
      batchLimit,
      deletedCount: typeof data === 'number' ? data : 0,
    });
  } catch (error) {
    return internalErrorResponse('archive_purge_failed', error);
  }
});

async function parseRequestBody(
  request: Request,
): Promise<Record<string, unknown>> {
  const text = await request.text();
  if (text.trim() === '') {
    return {};
  }

  const parsed = JSON.parse(text);
  return isRecord(parsed) ? parsed : {};
}

function normalizeBatchLimit(value: unknown) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return defaultBatchLimit;
  }

  return Math.min(Math.max(Math.floor(value), 1), 500);
}
