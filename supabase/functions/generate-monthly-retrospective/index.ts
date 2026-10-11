import { GenerateMonthlyRetrospective } from '../../../services/ai-api/src/application/generate-monthly-retrospective.ts';
import { MonthlyRetrospectiveModel } from '../../../services/ai-api/src/application/monthly-retrospective-model.ts';
import { SupabaseMonthlyRetrospectiveGateway } from '../../../services/ai-api/src/infrastructure/supabase-monthly-retrospective-gateway.ts';
import { SupabaseAccessTokenAuthenticator } from '../../../services/ai-api/src/infrastructure/supabase-proactive-suggestion-gateway.ts';
import { createMonthlyRetrospectiveHttpHandler } from '../../../services/ai-api/src/presentation/monthly-retrospective-http-handler.ts';
import { createAiLearningModel } from '../_shared/ai_learning_model.ts';
import { createServiceRoleClient } from '../_shared/supabase.ts';

const supabase = createServiceRoleClient();
Deno.serve(createMonthlyRetrospectiveHttpHandler({
  authenticator: new SupabaseAccessTokenAuthenticator(supabase),
  generator: new GenerateMonthlyRetrospective({
    gateway: new SupabaseMonthlyRetrospectiveGateway(supabase),
    model: () => new MonthlyRetrospectiveModel(createAiLearningModel({timeoutMs:50_000}).client),
  }),
}));
