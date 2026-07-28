import type { AccountDeletionAuthenticator } from './account_deletion_http_handler.ts';
import type { AccountDeletionGateway } from './account_deletion_service.ts';

type SupabaseError = unknown;

type SupabaseUserResult = {
  data: {
    user: { id: string } | null;
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
    return userId ? { userId } : null;
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
