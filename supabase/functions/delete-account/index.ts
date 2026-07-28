import { createServiceRoleClient } from '../_shared/supabase.ts';
import { createAccountDeletionHttpHandler } from './account_deletion_http_handler.ts';
import { AccountDeletionService } from './account_deletion_service.ts';
import {
  SupabaseAccountDeletionAuthenticator,
  SupabaseAccountDeletionGateway,
} from './supabase_account_deletion_gateway.ts';

const supabase = createServiceRoleClient();
const gateway = new SupabaseAccountDeletionGateway(supabase);
const deletionService = new AccountDeletionService(gateway);

Deno.serve(createAccountDeletionHttpHandler({
  authenticator: new SupabaseAccountDeletionAuthenticator(supabase),
  deletionService,
  onError: (error) => console.error('[delete-account]', error),
}));
