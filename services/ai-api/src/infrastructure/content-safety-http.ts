const maximumResponseBytes = 65_536;

export function requireContentSafetyCredential(value: string): string {
  if (typeof value !== 'string' || value.trim().length === 0 || /[\r\n]/.test(value)) {
    throw new TypeError('content safety credential is required');
  }
  return value.trim();
}

export async function requestContentSafetyJson(options: {
  endpoint: string; token: string; body: unknown; signal: AbortSignal; fetcher: typeof fetch;
}): Promise<unknown> {
  try {
    const response = await options.fetcher(options.endpoint, {
      method: 'POST', redirect: 'error', signal: options.signal,
      headers: { authorization: `Bearer ${options.token}`, 'content-type': 'application/json' },
      body: JSON.stringify(options.body),
    });
    if (!response.ok || response.body === null) {
      await response.body?.cancel();
      throw new Error();
    }
    const reader = response.body.getReader();
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      for (;;) {
        const chunk = await reader.read();
        if (chunk.done) break;
        size += chunk.value.byteLength;
        if (size > maximumResponseBytes) {
          await reader.cancel();
          throw new Error();
        }
        chunks.push(chunk.value);
      }
    } finally { reader.releaseLock(); }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    // Upstream responses may contain submitted content or credentials.
    throw new Error('content_safety_provider_unavailable');
  }
}

export function isContentSafetyRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
