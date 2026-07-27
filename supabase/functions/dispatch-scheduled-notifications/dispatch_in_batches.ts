export async function dispatchInBatches<T, R>(
  items: readonly T[],
  concurrency: number,
  dispatch: (item: T) => Promise<R>,
) {
  if (!Number.isInteger(concurrency) || concurrency < 1) {
    throw new RangeError('concurrency must be a positive integer');
  }

  const results: R[] = [];
  for (let offset = 0; offset < items.length; offset += concurrency) {
    const batch = items.slice(offset, offset + concurrency);
    const batchResults = await Promise.all(batch.map(dispatch));
    results.push(...batchResults);
  }
  return results;
}
