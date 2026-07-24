import {
  ProactiveSuggestionContextError,
  type GeneratedProactiveSuggestion,
  type ProactiveSuggestionCoordinates,
} from '../application/generate-proactive-suggestion.ts';

interface AccessTokenAuthenticator {
  authenticate(accessToken: string): Promise<string | null>;
}

interface ProactiveSuggestionGenerator {
  execute(input: {
    userId: string;
    coordinates: ProactiveSuggestionCoordinates | null;
  }): Promise<GeneratedProactiveSuggestion>;
}

interface ProactiveSuggestionHttpHandlerOptions {
  authenticator: AccessTokenAuthenticator;
  generator: ProactiveSuggestionGenerator;
  onError?: (errorType: string) => void;
}

export function createProactiveSuggestionHttpHandler(
  options: ProactiveSuggestionHttpHandlerOptions,
): (request: Request) => Promise<Response> {
  const onError = options.onError ?? logSafeError;

  return async (request: Request): Promise<Response> => {
    if (request.method !== 'POST') {
      return jsonResponse(405, { error: 'method_not_allowed' });
    }

    const token = bearerToken(request.headers.get('authorization'));
    if (token === null) {
      return jsonResponse(401, { error: 'unauthorized' });
    }

    let userId: string | null;
    try {
      userId = await options.authenticator.authenticate(token);
    } catch {
      userId = null;
    }
    if (userId === null) {
      return jsonResponse(401, { error: 'unauthorized' });
    }

    let coordinates: ProactiveSuggestionCoordinates | null;
    try {
      coordinates = parseCoordinates(await parseRequestBody(request));
    } catch {
      return jsonResponse(400, { error: 'invalid_request' });
    }

    try {
      const suggestion = await options.generator.execute({
        userId,
        coordinates,
      });
      return jsonResponse(200, serializeSuggestion(suggestion));
    } catch (error) {
      if (error instanceof ProactiveSuggestionContextError) {
        return jsonResponse(
          error.code === 'ai_personalization_not_ready' ? 409 : 503,
          { error: error.code },
        );
      }

      onError(error instanceof Error ? error.name : 'UnknownError');
      return jsonResponse(503, { error: 'ai_suggestion_unavailable' });
    }
  };
}

async function parseRequestBody(
  request: Request,
): Promise<Record<string, unknown>> {
  const text = await request.text();
  if (text.trim().length === 0) {
    return {};
  }
  const value = JSON.parse(text);
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new TypeError('request body must be an object');
  }
  return value as Record<string, unknown>;
}

function parseCoordinates(
  body: Record<string, unknown>,
): ProactiveSuggestionCoordinates | null {
  const latitude = body.latitude;
  const longitude = body.longitude;
  if (latitude === undefined && longitude === undefined) {
    return null;
  }
  if (
    typeof latitude !== 'number'
    || !Number.isFinite(latitude)
    || latitude < -90
    || latitude > 90
    || typeof longitude !== 'number'
    || !Number.isFinite(longitude)
    || longitude < -180
    || longitude > 180
  ) {
    throw new RangeError('invalid coordinates');
  }
  return { latitude, longitude };
}

function bearerToken(value: string | null): string | null {
  if (value === null || !value.startsWith('Bearer ')) {
    return null;
  }
  const token = value.slice('Bearer '.length).trim();
  return token.length === 0 ? null : token;
}

function serializeSuggestion(
  suggestion: GeneratedProactiveSuggestion,
): Record<string, unknown> {
  return {
    suggestion_id: suggestion.suggestionId,
    text: suggestion.text,
    kind: suggestion.kind,
    generated_at: suggestion.generatedAt,
    valid_until: suggestion.validUntil,
    context_date: suggestion.contextDate,
    has_card_today: suggestion.hasCardToday,
  };
}

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  });
}

function logSafeError(errorType: string): void {
  console.error('ai_proactive_suggestion_failed', errorType);
}
