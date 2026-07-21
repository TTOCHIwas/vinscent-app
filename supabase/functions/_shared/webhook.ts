export type WebhookSecretOptions = {
  envName: string;
  headerName: string;
  fallbackEnvName?: string;
  fallbackHeaderName?: string;
};

export type EnvironmentReader = (name: string) => string | undefined;

const readDenoEnvironment: EnvironmentReader = (name) => Deno.env.get(name);

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

export function verifyWebhookSecret(
  request: Request,
  options: WebhookSecretOptions,
  readEnvironment: EnvironmentReader = readDenoEnvironment,
) {
  const configuredSecret =
    readEnvironment(options.envName) ??
    (options.fallbackEnvName
      ? readEnvironment(options.fallbackEnvName)
      : undefined);
  const requestSecret =
    request.headers.get(options.headerName) ??
    (options.fallbackHeaderName
      ? request.headers.get(options.fallbackHeaderName)
      : null);

  return Boolean(configuredSecret && requestSecret === configuredSecret);
}

export function extractWebhookRecordId(payload: unknown) {
  if (!isRecord(payload)) {
    throw new Error('payload must be an object');
  }

  const candidate = isRecord(payload.record) ? payload.record : payload;
  if (typeof candidate.id !== 'string' || candidate.id === '') {
    throw new Error('missing id');
  }

  return candidate.id;
}
