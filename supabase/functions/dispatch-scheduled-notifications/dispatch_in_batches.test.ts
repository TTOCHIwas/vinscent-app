import assert from 'node:assert/strict';
import test from 'node:test';

import { dispatchInBatches } from './dispatch_in_batches.ts';

test('dispatchInBatches preserves order and bounds concurrency', async () => {
  let activeCount = 0;
  let maximumActiveCount = 0;

  const results = await dispatchInBatches(
    [1, 2, 3, 4, 5],
    2,
    async (value) => {
      activeCount += 1;
      maximumActiveCount = Math.max(maximumActiveCount, activeCount);
      await new Promise((resolve) => setTimeout(resolve, 1));
      activeCount -= 1;
      return value * 2;
    },
  );

  assert.deepEqual(results, [2, 4, 6, 8, 10]);
  assert.equal(maximumActiveCount, 2);
});

test('dispatchInBatches rejects an invalid concurrency', async () => {
  await assert.rejects(
    () => dispatchInBatches([1], 0, async (value) => value),
    RangeError,
  );
});

test('dispatchInBatches attempts later batches after one item fails', async () => {
  const attemptedValues: number[] = [];

  await assert.rejects(
    () =>
      dispatchInBatches([1, 2, 3, 4], 2, async (value) => {
        attemptedValues.push(value);
        if (value === 2) {
          throw new Error('dispatch failed');
        }
        return value;
      }),
    AggregateError,
  );

  assert.deepEqual(attemptedValues, [1, 2, 3, 4]);
});
