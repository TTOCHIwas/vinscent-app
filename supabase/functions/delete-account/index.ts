import { createServiceRoleClient } from '../_shared/supabase.ts';
import { requiredEnv } from '../_shared/environment.ts';
import { createAccountDeletionHttpHandler } from './account_deletion_http_handler.ts';
import { AccountDeletionService } from './account_deletion_service.ts';
import { AppleClientSecretSigner } from './apple_client_secret.ts';
import { AppleTokenRevoker } from './apple_token_revoker.ts';
import {
  SupabaseAccountDeletionAuthenticator,
  SupabaseAccountDeletionGateway,
} from './supabase_account_deletion_gateway.ts';

const supabase = createServiceRoleClient();
const gateway = new SupabaseAccountDeletionGateway(supabase);
const deletionService = new AccountDeletionService(gateway, {
  async revokeAuthorizationCode(request) {
    const clientId = requiredEnv('APPLE_SIGN_IN_CLIENT_ID');
    const signer = new AppleClientSecretSigner({
      teamId: requiredEnv('APPLE_SIGN_IN_TEAM_ID'),
      keyId: requiredEnv('APPLE_SIGN_IN_KEY_ID'),
      clientId,
      privateKey: requiredEnv('APPLE_SIGN_IN_PRIVATE_KEY'),
    });
    const revoker = new AppleTokenRevoker({
      clientId,
      createClientSecret: () => signer.createClientSecret(),
      fetch,
    });
    await revoker.revokeAuthorizationCode(request);
  },
});

Deno.serve(createAccountDeletionHttpHandler({
  authenticator: new SupabaseAccountDeletionAuthenticator(supabase),
  deletionService,
  onError: (error) => console.error('[delete-account]', error),
}));
