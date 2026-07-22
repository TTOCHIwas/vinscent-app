import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'story_card_download_failure.dart';
import 'story_card_download_source.dart';
import 'story_card_scene.dart';

final storyCardDownloadRepositoryProvider =
    Provider<StoryCardDownloadRepository>((ref) {
      return const SupabaseStoryCardDownloadRepository();
    });

abstract interface class StoryCardDownloadRepository {
  Future<StoryCardDownloadSource> fetch(String cardId);
}

class SupabaseStoryCardDownloadRepository
    implements StoryCardDownloadRepository {
  const SupabaseStoryCardDownloadRepository();

  static const _bucketId = 'story-cards';
  static const _maxSceneBytes = 1024 * 1024;
  static const _maxBackgroundBytes = 5 * 1024 * 1024;

  @override
  Future<StoryCardDownloadSource> fetch(String cardId) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const StoryCardDownloadException(
        StoryCardDownloadFailureReason.configMissing,
      );
    }

    try {
      final row = await Supabase.instance.client
          .from('story_loop_cards')
          .select('scene_data_path, background_image_path')
          .eq('id', cardId)
          .maybeSingle()
          .timeout(AppConfig.supabaseRpcTimeout);
      if (row == null) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.cardNotFound,
        );
      }

      final sceneDataPath = row['scene_data_path'] as String?;
      final backgroundImagePath = row['background_image_path'] as String?;
      if (sceneDataPath == null || sceneDataPath.trim().isEmpty) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.invalidSource,
        );
      }

      final downloads = <Future<Uint8List>>[
        _bucket.download(sceneDataPath),
        if (backgroundImagePath != null) _bucket.download(backgroundImagePath),
      ];
      final results = await Future.wait(
        downloads,
      ).timeout(AppConfig.supabaseRpcTimeout);
      final sceneBytes = results.first;
      final backgroundImageBytes = backgroundImagePath == null
          ? null
          : results.last;

      if (sceneBytes.isEmpty || sceneBytes.length > _maxSceneBytes) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.invalidSource,
        );
      }
      if (backgroundImageBytes != null &&
          (backgroundImageBytes.isEmpty ||
              backgroundImageBytes.length > _maxBackgroundBytes)) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.invalidSource,
        );
      }

      return StoryCardDownloadSource(
        scene: _decodeScene(sceneBytes),
        backgroundImageBytes: backgroundImageBytes,
      );
    } on StoryCardDownloadException {
      rethrow;
    } on TimeoutException {
      throw const StoryCardDownloadException(
        StoryCardDownloadFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw StoryCardDownloadException(
        StoryCardDownloadFailureReason.sourceUnavailable,
        error.message,
      );
    } on StorageException catch (error) {
      throw StoryCardDownloadException(
        StoryCardDownloadFailureReason.sourceUnavailable,
        error.message,
      );
    } on TypeError catch (error) {
      throw StoryCardDownloadException(
        StoryCardDownloadFailureReason.invalidSource,
        error.toString(),
      );
    }
  }

  StorageFileApi get _bucket =>
      Supabase.instance.client.storage.from(_bucketId);

  StoryCardScene _decodeScene(Uint8List bytes) {
    try {
      return StoryCardScene.fromJsonString(utf8.decode(bytes));
    } catch (error) {
      throw StoryCardDownloadException(
        StoryCardDownloadFailureReason.invalidSource,
        error.toString(),
      );
    }
  }
}
