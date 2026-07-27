export async function dispatchInBatches<T, R>(
  items: readonly T[],
  concurrency: number,
  dispatch: (item: T) => Promise<R>,
) {
  if (!Number.isInteger(concurrency) || concurrency < 1) {
    throw new RangeError('concurrency must be a positive integer');
  }

  const results: R[] = [];
  const failures: unknown[] = [];
  for (let offset = 0; offset < items.length; offset += concurrency) {
    const batch = items.slice(offset, offset + concurrency);
    const batchResults = await Promise.allSettled(batch.map(dispatch));
    for (const result of batchResults) {
      if (result.status === 'fulfilled') {
        results.push(result.value);
      } else {
        failures.push(result.reason);
      }
    }
  }

  if (failures.length > 0) {
    throw new AggregateError(
      failures,
      `${failures.length} scheduled notification dispatches failed`,
    );
  }

  return results;
}
