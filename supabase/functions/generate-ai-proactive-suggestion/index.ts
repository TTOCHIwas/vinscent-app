import {
  validateProactiveSuggestion,
  type ProactiveSuggestionContext,
} from '../../../services/ai-api/src/domain/learning-contract.ts';
import { GeminiStructuredGenerationClient } from '../../../services/ai-api/src/infrastructure/gemini-structured-generation-client.ts';
import { GeminiLearningModel } from '../../../services/ai-api/src/infrastructure/gemini-learning-model.ts';
import { OpenMeteoForecastClient } from '../../../services/ai-api/src/infrastructure/open-meteo-forecast-client.ts';
import { parseProactiveSuggestionBaseContext } from '../../../services/ai-api/src/infrastructure/personalization-context-parser.ts';
import { requiredEnv } from '../_shared/environment.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';

const defaultModel = 'gemini-3.1-flash-lite';
const responseHeaders = {
  'content-type': 'application/json; charset=utf-8',
};

const supabase = createServiceRoleClient();
const model = new GeminiLearningModel(
  new GeminiStructuredGenerationClient({
    apiKey: requiredEnv('GEMINI_API_KEY'),
    model: optionalEnv('GEMINI_MODEL') ?? defaultModel,
    endpoint: optionalEnv('GEMINI_GENERATE_CONTENT_ENDPOINT'),
    timeoutMs: optionalPositiveIntegerEnv('GEMINI_TIMEOUT_MS'),
  }),
);

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse(405, { error: 'method_not_allowed' });
  }

  const token = bearerToken(request.headers.get('authorization'));
  if (token === null) {
    return jsonResponse(401, { error: 'unauthorized' });
  }

  const { data: userData, error: userError } = await supabase.auth.getUser(
    token,
  );
  if (userError !== null || userData.user === null) {
    return jsonResponse(401, { error: 'unauthorized' });
  }

  let coordinates: { latitude: number; longitude: number } | null;
  try {
    coordinates = parseCoordinates(await parseRequestBody(request));
  } catch {
    return jsonResponse(400, { error: 'invalid_request' });
  }

  const { data: rawContext, error: contextError } = await supabase.rpc(
    'get_ai_proactive_suggestion_context',
    { requested_user_id: userData.user.id },
  );
  if (contextError !== null) {
    const errorCode = safeErrorCode(contextError);
    return jsonResponse(
      errorCode === 'ai_personalization_not_ready' ? 409 : 503,
      { error: errorCode },
    );
  }

  try {
    const baseContext = parseProactiveSuggestionBaseContext(rawContext);
    const weather = coordinates === null
      ? null
      : await fetchWeatherSafely(coordinates);
    const context: ProactiveSuggestionContext = {
      localDate: baseContext.localDate,
      localHour: baseContext.localHour,
      hasCardToday: baseContext.hasCardToday,
      confirmedMemories: baseContext.confirmedMemories,
      recentCompletedQuestions: baseContext.recentCompletedQuestions,
      weather,
    };
    const result = await model.generateProactiveSuggestion(context);
    validateProactiveSuggestion(context, result.value);

    const now = new Date();
    const lifetimeMinutes = result.value.kind === 'sunset_card' ? 45 : 180;
    const desiredValidUntil = new Date(
      now.getTime() + lifetimeMinutes * 60 * 1000,
    );
    const validUntil = clampToLocalDate(
      desiredValidUntil,
      now,
      baseContext.localDate,
      baseContext.timezone,
    );

    return jsonResponse(200, {
      suggestion_id: crypto.randomUUID(),
      text: result.value.text,
      kind: result.value.kind,
      generated_at: now.toISOString(),
      valid_until: validUntil.toISOString(),
      context_date: baseContext.localDate,
      has_card_today: baseContext.hasCardToday,
    });
  } catch {
    return jsonResponse(503, { error: 'ai_suggestion_unavailable' });
  }
});

async function fetchWeatherSafely(
  coordinates: { latitude: number; longitude: number },
) {
  try {
    return await new OpenMeteoForecastClient({
      endpoint: optionalEnv('WEATHER_FORECAST_ENDPOINT'),
      apiKey: optionalEnv('OPEN_METEO_API_KEY'),
      timeoutMs: optionalPositiveIntegerEnv('WEATHER_TIMEOUT_MS'),
    }).fetchContext(coordinates.latitude, coordinates.longitude);
  } catch {
    return null;
  }
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
    throw new TypeError('invalid request body');
  }
  return value as Record<string, unknown>;
}

function parseCoordinates(
  body: Record<string, unknown>,
): { latitude: number; longitude: number } | null {
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

function clampToLocalDate(
  desired: Date,
  now: Date,
  contextDate: string,
  timezone: string,
): Date {
  const clamped = new Date(desired);
  while (
    clamped.getTime() > now.getTime()
    && localDateInTimeZone(clamped, timezone) !== contextDate
  ) {
    clamped.setTime(clamped.getTime() - 60 * 1000);
  }
  return clamped;
}

function localDateInTimeZone(value: Date, timezone: string): string {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(value);
  const year = parts.find((part) => part.type === 'year')?.value;
  const month = parts.find((part) => part.type === 'month')?.value;
  const day = parts.find((part) => part.type === 'day')?.value;
  if (year === undefined || month === undefined || day === undefined) {
    throw new TypeError('invalid context timezone');
  }
  return `${year}-${month}-${day}`;
}

function safeErrorCode(error: unknown): string {
  if (typeof error !== 'object' || error === null) {
    return 'ai_suggestion_context_unavailable';
  }
  const message = (error as Record<string, unknown>).message;
  return message === 'ai_personalization_not_ready'
    ? message
    : 'ai_suggestion_context_unavailable';
}

function jsonResponse(
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  });
}

function optionalEnv(name: string): string | undefined {
  const value = Deno.env.get(name)?.trim();
  return value ? value : undefined;
}

function optionalPositiveIntegerEnv(name: string): number | undefined {
  const value = optionalEnv(name);
  if (value === undefined) {
    return undefined;
  }

  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new RangeError(`${name} must be a positive integer`);
  }
  return parsed;
}
