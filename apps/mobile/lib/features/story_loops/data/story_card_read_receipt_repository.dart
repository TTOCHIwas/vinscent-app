import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'story_loop_read_failure.dart';

final storyCardReadReceiptRepositoryProvider =
    Provider<StoryCardReadReceiptRepository>((ref) {
      return const SupabaseStoryCardReadReceiptRepository();
    });

abstract interface class StoryCardReadReceiptRepository {
  Future<bool> acknowledgeCard({required String cardId});
}

class SupabaseStoryCardReadReceiptRepository
    implements StoryCardReadReceiptRepository {
  const SupabaseStoryCardReadReceiptRepository();

  @override
  Future<bool> acknowledgeCard({required String cardId}) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.configMissing,
      );
    }

    try {
      final result = await Supabase.instance.client
          .rpc('acknowledge_story_card', params: {'target_card_id': cardId})
          .timeout(AppConfig.supabaseRpcTimeout);
      return result == true;
    } on TimeoutException {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw StoryLoopReadRepositoryException(
        error.message == 'auth_required'
            ? StoryLoopReadFailureReason.authRequired
            : StoryLoopReadFailureReason.unknown,
        error.message,
      );
    }
  }
}
