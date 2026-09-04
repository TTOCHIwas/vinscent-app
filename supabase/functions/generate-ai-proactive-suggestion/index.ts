import {
  GenerateProactiveSuggestionUseCase,
  type ProactiveSuggestionWeatherClient,
} from '../../../services/ai-api/src/application/generate-proactive-suggestion.ts';
import {
  MetNorwayForecastClient,
} from '../../../services/ai-api/src/infrastructure/met-norway-forecast-client.ts';
import {
  SupabaseAccessTokenAuthenticator,
  SupabaseProactiveSuggestionContextSource,
  SupabaseProactiveSuggestionQuota,
} from '../../../services/ai-api/src/infrastructure/supabase-proactive-suggestion-gateway.ts';
import {
  createProactiveSuggestionHttpHandler,
} from '../../../services/ai-api/src/presentation/proactive-suggestion-http-handler.ts';
import {
  optionalEnv,
  requiredEnv,
} from '../_shared/environment.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';

const proactiveWeatherTimeoutMs = 5_000;

const supabase = createServiceRoleClient();
const generator = new GenerateProactiveSuggestionUseCase({
  contextSource: new SupabaseProactiveSuggestionContextSource(supabase),
  quota: new SupabaseProactiveSuggestionQuota(supabase),
  weatherClient: createWeatherClient(),
});

Deno.serve(createProactiveSuggestionHttpHandler({
  authenticator: new SupabaseAccessTokenAuthenticator(supabase),
  generator,
}));

function createWeatherClient(): ProactiveSuggestionWeatherClient | null {
  try {
    return new MetNorwayForecastClient({
      forecastEndpoint: optionalEnv('MET_NORWAY_FORECAST_ENDPOINT'),
      sunriseEndpoint: optionalEnv('MET_NORWAY_SUNRISE_ENDPOINT'),
      userAgent: requiredEnv('MET_NORWAY_USER_AGENT'),
      timeoutMs: proactiveWeatherTimeoutMs,
    });
  } catch {
    return null;
  }
}
