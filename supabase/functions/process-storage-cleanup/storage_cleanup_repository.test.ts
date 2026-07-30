import assert from 'node:assert/strict';
import test from 'node:test';

import {
  SupabaseStorageCleanupRepository,
} from './storage_cleanup_repository.ts';

test('maps storage cleanup RPC contracts without leaking database shapes', async () => {
  const calls: Array<[string, Record<string, unknown> | undefined]> = [];
  const repository = new SupabaseStorageCleanupRepository({
    async rpc(functionName, params) {
      calls.push([functionName, params]);
      if (functionName === 'reconcile_storage_cleanup_requests') {
        return { data: 4, error: null };
      }
      if (functionName === 'is_storage_cleanup_object_referenced') {
        return { data: true, error: null };
      }
      if (functionName === 'complete_storage_cleanup_request') {
        return { data: 'completed', error: null };
      }
      return {
        data: [{
          request_id: '10000000-0000-0000-0000-000000000001',
          claim_token: '20000000-0000-0000-0000-000000000001',
          attempt_count: 1,
          max_attempts: 5,
          bucket_id: 'story-cards',
          object_path: 'old/preview.png',
          cleanup_reason: 'orphan_story_card',
        }],
        error: null,
      };
    },
  });

  assert.equal(await repository.reconcile(50, 60), 4);
  assert.equal(
    await repository.isReferenced('story-cards', 'old/preview.png'),
    true,
  );
  assert.equal((await repository.claim(
    'worker-1',
    10,
    '10000000-0000-0000-0000-000000000001',
  )).length, 1);
  assert.equal(await repository.complete({
    requestId: '10000000-0000-0000-0000-000000000001',
    claimToken: '20000000-0000-0000-0000-000000000001',
    succeeded: true,
    outcome: 'deleted',
    retryDelaySeconds: 0,
  }), 'completed');

  assert.deepEqual(calls, [
    [
      'reconcile_storage_cleanup_requests',
      { requested_limit: 50, requested_minimum_age_minutes: 60 },
    ],
    [
      'is_storage_cleanup_object_referenced',
      {
        requested_bucket_id: 'story-cards',
        requested_object_path: 'old/preview.png',
      },
    ],
    [
      'claim_storage_cleanup_requests',
      {
        requested_worker_id: 'worker-1',
        requested_limit: 10,
        requested_request_id: '10000000-0000-0000-0000-000000000001',
      },
    ],
    [
      'complete_storage_cleanup_request',
      {
        requested_request_id: '10000000-0000-0000-0000-000000000001',
        requested_claim_token: '20000000-0000-0000-0000-000000000001',
        requested_succeeded: true,
        requested_outcome: 'deleted',
        requested_error: null,
        requested_retry_delay_seconds: 0,
      },
    ],
  ]);
});
