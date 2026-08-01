import {
  GenerateProactiveSuggestionUseCase,
} from '../../../services/ai-api/src/application/generate-proactive-suggestion.ts';
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
import { createAiLearningModel } from '../_shared/ai_learning_model.ts';
import {
  optionalEnv,
} from '../_shared/environment.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';

const proactiveModelTimeoutMs = 15_000;
const proactiveWeatherTimeoutMs = 5_000;

const supabase = createServiceRoleClient();
const aiRuntime = createAiLearningModel({
  timeoutMs: proactiveModelTimeoutMs,
});
const generator = new GenerateProactiveSuggestionUseCase({
  contextSource: new SupabaseProactiveSuggestionContextSource(supabase),
  quota: new SupabaseProactiveSuggestionQuota(supabase),
  model: aiRuntime.model,
  weatherClient: createWeatherClient(),
});

Deno.serve(createProactiveSuggestionHttpHandler({
  authenticator: new SupabaseAccessTokenAuthenticator(supabase),
  generator,
}));

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
