export type AccountDeletionResult = {
  deletedCoupleCount: number;
};

export interface AccountDeletionGateway {
  deleteSharedData(userId: string): Promise<number>;
  deleteAuthUser(userId: string): Promise<void>;
}

export class AccountDeletionService {
  private readonly gateway: AccountDeletionGateway;

  constructor(gateway: AccountDeletionGateway) {
    this.gateway = gateway;
  }

  async deleteAccount(userId: string): Promise<AccountDeletionResult> {
    const normalizedUserId = userId.trim();
    if (!normalizedUserId) {
      throw new Error('account_user_required');
    }

    const deletedCoupleCount = await this.gateway.deleteSharedData(
      normalizedUserId,
    );
    await this.gateway.deleteAuthUser(normalizedUserId);

    return { deletedCoupleCount };
  }
}
