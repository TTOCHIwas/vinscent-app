import type { AccountDeletionAuthenticator } from './account_deletion_http_handler.ts';
import type { AccountDeletionGateway } from './account_deletion_service.ts';

type SupabaseError = unknown;

type SupabaseIdentity = {
  provider?: unknown;
  id?: unknown;
  identity_data?: unknown;
};

type SupabaseUserResult = {
  data: {
    user: {
      id: string;
      identities?: SupabaseIdentity[] | null;
    } | null;
  };
  error: SupabaseError;
};

type SupabaseRpcResult = {
  data: unknown;
  error: SupabaseError;
};

type SupabaseAdminResult = {
  error: SupabaseError;
};

interface SupabaseAccountDeletionClient {
  auth: {
    getUser(accessToken: string): Promise<SupabaseUserResult>;
    admin: {
      deleteUser(userId: string): Promise<SupabaseAdminResult>;
    };
  };
  rpc(
    name: string,
    args: Record<string, unknown>,
  ): PromiseLike<SupabaseRpcResult>;
}

export class SupabaseAccountDeletionAuthenticator
  implements AccountDeletionAuthenticator {
  readonly #client: SupabaseAccountDeletionClient;

  constructor(client: SupabaseAccountDeletionClient) {
    this.#client = client;
  }

  async authenticate(accessToken: string) {
    const { data, error } = await this.#client.auth.getUser(accessToken);
    if (error !== null || data.user === null) {
      return null;
    }

    const userId = data.user.id.trim();
    if (!userId) {
      return null;
    }

    const appleSubject = appleSubjectFrom(data.user.identities);
    return appleSubject ? { userId, appleSubject } : { userId };
  }
}

export class SupabaseAccountDeletionGateway
  implements AccountDeletionGateway {
  readonly #client: SupabaseAccountDeletionClient;

  constructor(client: SupabaseAccountDeletionClient) {
    this.#client = client;
  }

  async deleteSharedData(userId: string): Promise<number> {
    const { data, error } = await this.#client.rpc(
      'delete_account_shared_data',
      { target_user_id: userId },
    );
    if (error !== null) {
      throw new Error('account_shared_data_deletion_failed', {
        cause: error,
      });
    }
    if (
      typeof data !== 'number' ||
      !Number.isInteger(data) ||
      data < 0
    ) {
      throw new Error('account_shared_data_deletion_invalid_result');
    }

    return data;
  }

  async deleteAuthUser(userId: string): Promise<void> {
    const { error } = await this.#client.auth.admin.deleteUser(userId);
    if (error !== null) {
      throw new Error('auth_user_deletion_failed', { cause: error });
    }
  }
}

function appleSubjectFrom(
  identities: SupabaseIdentity[] | null | undefined,
): string | null {
  const appleIdentity = identities?.find(
    (identity) => identity.provider === 'apple',
  );
  if (!appleIdentity) {
    return null;
  }

  const identityData = appleIdentity.identity_data;
  if (
    identityData !== null &&
    typeof identityData === 'object' &&
    !Array.isArray(identityData)
  ) {
    const subject = (identityData as Record<string, unknown>).sub;
    if (typeof subject === 'string' && subject.trim()) {
      return subject.trim();
    }
  }

  return typeof appleIdentity.id === 'string' && appleIdentity.id.trim()
    ? appleIdentity.id.trim()
    : null;
}
