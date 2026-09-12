import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'story_card_download_failure.dart';
import 'story_card_download_source.dart';
import 'story_card_scene.dart';
import 'story_card_type.dart';

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
  static const _maxCompositeBytes = 12 * 1024 * 1024;

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
          .select(
            'card_type, preview_path, scene_data_path, background_image_path',
          )
          .eq('id', cardId)
          .maybeSingle()
          .timeout(AppConfig.supabaseRpcTimeout);
      if (row == null) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.cardNotFound,
        );
      }

      final sceneDataPath = row['scene_data_path'] as String?;
      final previewPath = row['preview_path'] as String?;
      final backgroundImagePath = row['background_image_path'] as String?;
      final cardType = StoryCardType.fromStorageValue(
        row['card_type'] as String?,
      );
      if (sceneDataPath == null || sceneDataPath.trim().isEmpty) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.invalidSource,
        );
      }

      final imagePath = cardType.isFourCut ? previewPath : backgroundImagePath;
      if (cardType.isFourCut &&
          (imagePath == null || imagePath.trim().isEmpty)) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.invalidSource,
        );
      }

      final downloads = <Future<Uint8List>>[
        _bucket.download(sceneDataPath),
        if (imagePath != null) _bucket.download(imagePath),
      ];
      final results = await Future.wait(
        downloads,
      ).timeout(AppConfig.supabaseRpcTimeout);
      final sceneBytes = results.first;
      final imageBytes = imagePath == null ? null : results.last;

      if (sceneBytes.isEmpty || sceneBytes.length > _maxSceneBytes) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.invalidSource,
        );
      }
      final maxImageBytes = cardType.isFourCut
          ? _maxCompositeBytes
          : _maxBackgroundBytes;
      if (imageBytes != null &&
          (imageBytes.isEmpty || imageBytes.length > maxImageBytes)) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.invalidSource,
        );
      }

      final decodedScene = _decodeScene(sceneBytes);
      final scene = decodedScene.cardType == cardType
          ? decodedScene
          : decodedScene.copyWith(cardType: cardType);

      return StoryCardDownloadSource(
        scene: scene,
        backgroundImageBytes: cardType.isFourCut ? null : imageBytes,
        compositeImageBytes: cardType.isFourCut ? imageBytes : null,
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
