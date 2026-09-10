import type { createServiceRoleClient } from '../_shared/supabase.ts';

const rolloverBatchSize = 200;

export type StoryCardRolloverResult = {
  status: 'ok' | 'failed';
  finalizedCount: number;
};

export async function finalizeExpiredStoryCards(
  supabase: ReturnType<typeof createServiceRoleClient>,
  runAt: Date,
) {
  const { data, error } = await supabase.rpc(
    'finalize_expired_story_cards',
    {
      requested_run_at: runAt.toISOString(),
      requested_limit: rolloverBatchSize,
    },
  );

  if (error) {
    throw new Error(`story_card_rollover_failed:${error.message}`);
  }

  return typeof data === 'number' ? data : 0;
}

export async function finalizeExpiredStoryCardsSafely(
  supabase: ReturnType<typeof createServiceRoleClient>,
  runAt: Date,
  onError: (error: unknown) => void = logStoryCardRolloverError,
): Promise<StoryCardRolloverResult> {
  try {
    return {
      status: 'ok',
      finalizedCount: await finalizeExpiredStoryCards(supabase, runAt),
    };
  } catch (error) {
    onError(error);
    return {
      status: 'failed',
      finalizedCount: 0,
    };
  }
}

function logStoryCardRolloverError(error: unknown) {
  const errorType = error instanceof Error ? error.name : 'UnknownError';
  console.error('story_card_rollover_failed', errorType);
}
