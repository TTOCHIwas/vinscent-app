export type AccountDeletionResult = {
  deletedCoupleCount: number;
};

export interface AccountDeletionGateway {
  deleteSharedData(userId: string): Promise<number>;
  deleteAuthUser(userId: string): Promise<void>;
}

export interface AppleAuthorizationRevoker {
  revokeAuthorizationCode(request: {
    authorizationCode: string;
    expectedSubject: string;
  }): Promise<void>;
}

export type AccountDeletionOptions = {
  appleSubject?: string;
  appleAuthorizationCode?: string;
};

export class AccountDeletionService {
  private readonly gateway: AccountDeletionGateway;
  private readonly appleAuthorizationRevoker?: AppleAuthorizationRevoker;

  constructor(
    gateway: AccountDeletionGateway,
    appleAuthorizationRevoker?: AppleAuthorizationRevoker,
  ) {
    this.gateway = gateway;
    this.appleAuthorizationRevoker = appleAuthorizationRevoker;
  }

  async deleteAccount(
    userId: string,
    options: AccountDeletionOptions = {},
  ): Promise<AccountDeletionResult> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('account_user_required');
    }

    await this.#revokeAppleAuthorization(options);

    const deletedCoupleCount = await this.gateway.deleteSharedData(
      normalizedUserId,
    );
    await this.gateway.deleteAuthUser(normalizedUserId);

    return { deletedCoupleCount };
  }

  async #revokeAppleAuthorization(
    options: AccountDeletionOptions,
  ): Promise<void> {
    const appleSubject = options.appleSubject?.trim();
    if (!appleSubject) {
      return;
    }

    const authorizationCode = options.appleAuthorizationCode?.trim();
    if (!authorizationCode) {
      throw new Error('apple_reauthentication_required');
    }
    if (!this.appleAuthorizationRevoker) {
      throw new Error('apple_token_revoker_unavailable');
    }

    await this.appleAuthorizationRevoker.revokeAuthorizationCode({
      authorizationCode,
      expectedSubject: appleSubject,
    });
  }
}
