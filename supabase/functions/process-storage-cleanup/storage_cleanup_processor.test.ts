import assert from 'node:assert/strict';
import test from 'node:test';

import type {
  ClaimedStorageCleanupRequest,
  CompleteStorageCleanupRequest,
  StorageCleanupCompletionStatus,
} from './storage_cleanup_contract.ts';
import { StorageCleanupProcessor } from './storage_cleanup_processor.ts';

const cleanupRequest: ClaimedStorageCleanupRequest = {
  requestId: '10000000-0000-0000-0000-000000000001',
  claimToken: '20000000-0000-0000-0000-000000000001',
  attemptCount: 1,
  maxAttempts: 5,
  bucketId: 'story-cards',
  objectPath: 'couple/loops/old/preview.png',
  cleanupReason: 'orphan_story_card',
};

test('reconciles and deletes unreferenced storage objects in a batch', async () => {
  const completions: CompleteStorageCleanupRequest[] = [];
  const removals: Array<[string, string]> = [];
  const processor = new StorageCleanupProcessor({
    workerId: 'storage-worker-1',
    repository: {
      async reconcile(limit, minimumAgeMinutes) {
        assert.equal(limit, 40);
        assert.equal(minimumAgeMinutes, 60);
        return 3;
      },
      async claim(workerId, limit, requestId) {
        assert.equal(workerId, 'storage-worker-1');
        assert.equal(limit, 10);
        assert.equal(requestId, undefined);
        return [cleanupRequest];
      },
      async isReferenced() {
        return false;
      },
      async complete(request) {
        completions.push(request);
        return 'completed';
      },
    },
    objectStore: {
      async remove(bucketId, objectPath) {
        removals.push([bucketId, objectPath]);
      },
    },
  });

  assert.deepEqual(await processor.processBatch({
    limit: 10,
    reconcileLimit: 40,
    minimumAgeMinutes: 60,
  }), {
    reconciled: 3,
    claimed: 1,
    deleted: 1,
    preserved: 0,
    retried: 0,
    failed: 0,
    stale: 0,
  });
  assert.deepEqual(removals, [[
    cleanupRequest.bucketId,
    cleanupRequest.objectPath,
  ]]);
  assert.deepEqual(completions, [{
    requestId: cleanupRequest.requestId,
    claimToken: cleanupRequest.claimToken,
    succeeded: true,
    outcome: 'deleted',
    retryDelaySeconds: 0,
  }]);
});

test('preserves objects that became referenced before deletion', async () => {
  const completions: CompleteStorageCleanupRequest[] = [];
  let removalCount = 0;
  const processor = new StorageCleanupProcessor({
    workerId: 'storage-worker-1',
    repository: {
      async reconcile() {
        return 0;
      },
      async claim() {
        return [cleanupRequest];
      },
      async isReferenced(bucketId, objectPath) {
        assert.equal(bucketId, cleanupRequest.bucketId);
        assert.equal(objectPath, cleanupRequest.objectPath);
        return true;
      },
      async complete(request) {
        completions.push(request);
        return 'completed';
      },
    },
    objectStore: {
      async remove() {
        removalCount += 1;
      },
    },
  });

  const result = await processor.processRequest(cleanupRequest.requestId);

  assert.equal(result.status, 'completed');
  assert.equal(result.outcome, 'still_referenced');
  assert.equal(removalCount, 0);
  assert.deepEqual(completions, [{
    requestId: cleanupRequest.requestId,
    claimToken: cleanupRequest.claimToken,
    succeeded: true,
    outcome: 'still_referenced',
    retryDelaySeconds: 0,
  }]);
});

test('returns transient deletion failures to the retry queue', async () => {
  const completions: CompleteStorageCleanupRequest[] = [];
  const processor = new StorageCleanupProcessor({
    workerId: 'storage-worker-1',
    repository: {
      async reconcile() {
        return 0;
      },
      async claim() {
        return [{ ...cleanupRequest, attemptCount: 3 }];
      },
      async isReferenced() {
        return false;
      },
      async complete(request) {
        completions.push(request);
        return 'pending';
      },
    },
    objectStore: {
      async remove() {
        throw new Error('private storage provider response');
      },
    },
    onError() {},
  });

  const result = await processor.processRequest(cleanupRequest.requestId);

  assert.equal(result.status, 'pending');
  assert.deepEqual(completions, [{
    requestId: cleanupRequest.requestId,
    claimToken: cleanupRequest.claimToken,
    succeeded: false,
    errorCode: 'storage_object_delete_failed',
    retryDelaySeconds: 240,
  }]);
});

test('counts terminal and stale completion outcomes independently', async () => {
  const statuses: StorageCleanupCompletionStatus[] = ['failed', 'stale'];
  const processor = new StorageCleanupProcessor({
    workerId: 'storage-worker-1',
    repository: {
      async reconcile() {
        return 0;
      },
      async claim() {
        return [
          cleanupRequest,
          {
            ...cleanupRequest,
            requestId: '10000000-0000-0000-0000-000000000002',
            claimToken: '20000000-0000-0000-0000-000000000002',
          },
        ];
      },
      async isReferenced() {
        return false;
      },
      async complete() {
        return statuses.shift() ?? 'failed';
      },
    },
    objectStore: {
      async remove() {
        throw new Error('temporary failure');
      },
    },
    onError() {},
  });

  assert.deepEqual(await processor.processBatch({
    limit: 2,
    reconcileLimit: 0,
    minimumAgeMinutes: 60,
  }), {
    reconciled: 0,
    claimed: 2,
    deleted: 0,
    preserved: 0,
    retried: 0,
    failed: 1,
    stale: 1,
  });
});
