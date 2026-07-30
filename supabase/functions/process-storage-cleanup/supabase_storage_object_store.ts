import type {
  StorageObjectStore,
} from './storage_cleanup_contract.ts';

type StorageRemovalResult = {
  error: { message: string } | null;
};

export interface SupabaseStorageClient {
  storage: {
    from(bucketId: string): {
      remove(paths: string[]): PromiseLike<StorageRemovalResult>;
    };
  };
}

export class SupabaseStorageObjectStore implements StorageObjectStore {
  readonly #client: SupabaseStorageClient;

  constructor(client: SupabaseStorageClient) {
    this.#client = client;
  }

  async remove(bucketId: string, objectPath: string): Promise<void> {
    const { error } = await this.#client.storage
      .from(bucketId)
      .remove([objectPath]);
    if (error !== null) {
      throw new Error(`storage_object_remove_failed:${error.message}`);
    }
  }
}
