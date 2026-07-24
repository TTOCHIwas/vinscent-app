import {
  GenerateProactiveSuggestionUseCase,
} from '../../../services/ai-api/src/application/generate-proactive-suggestion.ts';
import {
  GeminiStructuredGenerationClient,
} from '../../../services/ai-api/src/infrastructure/gemini-structured-generation-client.ts';
import {
  GeminiLearningModel,
} from '../../../services/ai-api/src/infrastructure/gemini-learning-model.ts';
import {
  OpenMeteoForecastClient,
} from '../../../services/ai-api/src/infrastructure/open-meteo-forecast-client.ts';
import {
  SupabaseAccessTokenAuthenticator,
  SupabaseProactiveSuggestionContextSource,
  SupabaseProactiveSuggestionQuota,
} from '../../../services/ai-api/src/infrastructure/supabase-proactive-suggestion-gateway.ts';
import {
  createProactiveSuggestionHttpHandler,
} from '../../../services/ai-api/src/presentation/proactive-suggestion-http-handler.ts';
import { requiredEnv } from '../_shared/environment.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';

const defaultModel = 'gemini-3.1-flash-lite';
const proactiveModelTimeoutMs = 15_000;
const proactiveWeatherTimeoutMs = 5_000;

const supabase = createServiceRoleClient();
const model = new GeminiLearningModel(
  new GeminiStructuredGenerationClient({
    apiKey: requiredEnv('GEMINI_API_KEY'),
    model: optionalEnv('GEMINI_MODEL') ?? defaultModel,
    endpoint: optionalEnv('GEMINI_GENERATE_CONTENT_ENDPOINT'),
    timeoutMs: proactiveModelTimeoutMs,
  }),
);
const generator = new GenerateProactiveSuggestionUseCase({
  contextSource: new SupabaseProactiveSuggestionContextSource(supabase),
  quota: new SupabaseProactiveSuggestionQuota(supabase),
  model,
  weatherClient: createWeatherClient(),
});

Deno.serve(createProactiveSuggestionHttpHandler({
  authenticator: new SupabaseAccessTokenAuthenticator(supabase),
  generator,
}));

function optionalEnv(name: string): string | undefined {
  const value = Deno.env.get(name)?.trim();
  return value ? value : undefined;
}

function createWeatherClient(): OpenMeteoForecastClient | null {
  try {
    return new OpenMeteoForecastClient({
      endpoint: optionalEnv('WEATHER_FORECAST_ENDPOINT'),
      apiKey: optionalEnv('OPEN_METEO_API_KEY'),
      timeoutMs: proactiveWeatherTimeoutMs,
    });
  } catch {
    return null;
  }
}
