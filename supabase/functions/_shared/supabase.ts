import { createClient } from 'npm:@supabase/supabase-js@2.86.0';

import { requiredEnv } from './environment.ts';

export function createServiceRoleClient() {
  return createClient(
    requiredEnv('SUPABASE_URL'),
    requiredEnv('SUPABASE_SERVICE_ROLE_KEY'),
  );
}
