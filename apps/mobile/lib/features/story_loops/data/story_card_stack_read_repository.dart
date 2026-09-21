import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/signed_url_cache.dart';
import 'story_card_stack_item.dart';
import 'story_card_stack_preview.dart';
import 'story_loop_read_failure.dart';

final storyCardStackReadRepositoryProvider =
    Provider<StoryCardStackReadRepository>((ref) {
      return SupabaseStoryCardStackReadRepository(
        signedUrlCache: ref.watch(signedUrlCacheProvider),
      );
    });

abstract interface class StoryCardStackReadRepository {
  Future<List<StoryCardStackPreview>> fetchTodayStacks();

  Future<List<StoryCardStackItem>> fetchStack({
    required DateTime date,
    required String authorUserId,
  });
}

class SupabaseStoryCardStackReadRepository
    implements StoryCardStackReadRepository {
  const SupabaseStoryCardStackReadRepository({
    required SignedUrlCache signedUrlCache,
  }) : _signedUrlCache = signedUrlCache;

  static const _bucketId = 'story-cards';
  static const _previewSignedUrlExpiresInSeconds = 60 * 60;

  final SignedUrlCache _signedUrlCache;

  @override
  Future<List<StoryCardStackPreview>> fetchTodayStacks() async {
    final rows = await _runRows('get_today_story_card_stacks_v3');
    final previewUrls = await _createPreviewUrls(
      rows.map((row) => row['latest_card_preview_path'] as String),
    );
    return rows
        .map(
          (row) => StoryCardStackPreview.fromJson(
            row,
            previewUrl: previewUrls[row['latest_card_preview_path']],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<StoryCardStackItem>> fetchStack({
    required DateTime date,
    required String authorUserId,
  }) async {
    final rows = await _runRows(
      'get_story_card_stack_v3',
      params: {
        'target_date': _formatDate(date),
        'target_author_user_id': authorUserId,
      },
    );
    final previewUrls = await _createPreviewUrls(
      rows.map((row) => row['preview_path'] as String),
    );
    return rows
        .map(
          (row) => StoryCardStackItem.fromJson(
            row,
            previewUrl: previewUrls[row['preview_path']],
          ),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _runRows(
    String functionName, {
    Map<String, Object?>? params,
  }) async {
    _ensureSupabaseConfigured();
    try {
      final data = await Supabase.instance.client
          .rpc(functionName, params: params)
          .timeout(AppConfig.supabaseRpcTimeout);
      if (data == null) {
        return const [];
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
      if (data is Map) {
        return [Map<String, dynamic>.from(data)];
      }
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.unknown,
      );
    } on TimeoutException {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw StoryLoopReadRepositoryException(
        _reasonFromMessage(error.message),
        error.message,
      );
    }
  }

  Future<Map<String, String>> _createPreviewUrls(Iterable<String> paths) async {
    try {
      return _signedUrlCache.resolve(
        bucketId: _bucketId,
        paths: paths,
        expiresInSeconds: _previewSignedUrlExpiresInSeconds,
        loader: (missingPaths, expiresInSeconds) async {
          final signedUrls = await Supabase.instance.client.storage
              .from(_bucketId)
              .createSignedUrls(missingPaths, expiresInSeconds)
              .timeout(AppConfig.supabaseRpcTimeout);
          return {
            for (final signedUrl in signedUrls)
              if (signedUrl.path.isNotEmpty)
                signedUrl.path: signedUrl.signedUrl,
          };
        },
      );
    } on TimeoutException {
      return const {};
    } on StorageException {
      return const {};
    }
  }

  void _ensureSupabaseConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.configMissing,
      );
    }
  }

  StoryLoopReadFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => StoryLoopReadFailureReason.authRequired,
      'relationship_date_required' =>
        StoryLoopReadFailureReason.relationshipDateRequired,
      _ => StoryLoopReadFailureReason.unknown,
    };
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
