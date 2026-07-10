import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import 'editable_story_loop_card.dart';
import 'story_card_draft.dart';
import 'story_card_scene.dart';
import 'story_loop_write_failure.dart';

final storyLoopWriteRepositoryProvider = Provider<StoryLoopWriteRepository>((
  ref,
) {
  return const SupabaseStoryLoopWriteRepository();
});

abstract interface class StoryLoopWriteRepository {
  Future<EditableStoryLoopCard?> fetchEditableTodayCard();

  Future<StoryLoopCardSaveResult> saveTodayCard({
    required String coupleId,
    required DateTime coupleDate,
    required String userId,
    required StoryCardDraft draft,
    required Uint8List previewImageBytes,
  });

  Future<void> deleteTodayCard({required int expectedRevision});
}

class SupabaseStoryLoopWriteRepository implements StoryLoopWriteRepository {
  const SupabaseStoryLoopWriteRepository();

  static const _bucketId = 'story-cards';

  @override
  Future<EditableStoryLoopCard?> fetchEditableTodayCard() async {
    _ensureSupabaseConfigured();

    try {
      final data = await Supabase.instance.client
          .rpc('get_my_today_story_loop_card_for_editing')
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asOptionalRow(data);
      if (row == null) {
        return null;
      }

      final sceneDataPath = row['scene_data_path'] as String;
      final sceneBytes = await _bucket
          .download(sceneDataPath)
          .timeout(AppConfig.supabaseRpcTimeout);
      final backgroundImagePath = row['background_image_path'] as String?;
      final backgroundImageBytes = backgroundImagePath == null
          ? null
          : await _bucket
              .download(backgroundImagePath)
              .timeout(AppConfig.supabaseRpcTimeout);

      return EditableStoryLoopCard(
        storyLoopId: row['story_loop_id'] as String,
        cardId: row['card_id'] as String,
        revision: _toInt(row['card_revision']),
        scene: StoryCardScene.fromJsonString(utf8.decode(sceneBytes)),
        backgroundImageBytes: backgroundImageBytes,
      );
    } on TimeoutException {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on StorageException catch (error) {
      throw _mapStorageError(error);
    } on FormatException catch (error) {
      throw StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.unknown,
        error.message,
      );
    }
  }

  @override
  Future<StoryLoopCardSaveResult> saveTodayCard({
    required String coupleId,
    required DateTime coupleDate,
    required String userId,
    required StoryCardDraft draft,
    required Uint8List previewImageBytes,
  }) async {
    _ensureSupabaseConfigured();
    _validateDraft(draft);

    final artifactRevision = Uuid().v4();
    final artifactPaths = _StoryCardArtifactPaths(
      coupleId: coupleId,
      coupleDate: coupleDate,
      userId: userId,
      artifactRevision: artifactRevision,
    );
    var uploadAttempted = false;

    try {
      uploadAttempted = true;
      await _bucket
          .uploadBinary(
            artifactPaths.previewPath,
            previewImageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              cacheControl: '60',
            ),
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      await _bucket
          .uploadBinary(
            artifactPaths.sceneDataPath,
            Uint8List.fromList(utf8.encode(draft.scene.toJsonString())),
            fileOptions: const FileOptions(
              contentType: 'application/json',
              cacheControl: '60',
            ),
          )
          .timeout(AppConfig.supabaseRpcTimeout);

      final backgroundImageBytes = draft.backgroundImageBytes;
      if (backgroundImageBytes != null) {
        await _bucket
            .uploadBinary(
              artifactPaths.backgroundImagePath,
              backgroundImageBytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '60',
              ),
            )
            .timeout(AppConfig.supabaseRpcTimeout);
      }

      final data = await Supabase.instance.client
          .rpc(
            'upsert_today_story_loop_card',
            params: {
              'requested_artifact_revision': artifactRevision,
              'requested_preview_path': artifactPaths.previewPath,
              'requested_scene_data_path': artifactPaths.sceneDataPath,
              'requested_background_image_path': backgroundImageBytes == null
                  ? null
                  : artifactPaths.backgroundImagePath,
              'requested_has_photo': backgroundImageBytes != null,
              'requested_has_drawing': draft.scene.hasDrawing,
              'requested_has_text': draft.scene.hasText,
              'requested_text_layer_count': draft.scene.textLayers.length,
              'requested_text_character_count':
                  draft.scene.textCharacterCount,
              'expected_revision': draft.existingRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asRow(data);

      return StoryLoopCardSaveResult(
        storyLoopId: row['story_loop_id'] as String,
        storyLoopStatus: row['story_loop_status'] as String,
        cardId: row['card_id'] as String,
        cardRevision: _toInt(row['card_revision']),
        questionGenerated: row['question_generated'] as bool? ?? false,
        dailyQuestionId: row['daily_question_id'] as String?,
      );
    } on TimeoutException {
      final error = const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.requestTimeout,
      );
      await _discardUploadedArtifactsIfNeeded(
        uploadAttempted: uploadAttempted,
        artifactRevision: artifactRevision,
      );
      throw error;
    } on PostgrestException catch (error) {
      final mappedError = _mapPostgrestError(error);
      await _discardUploadedArtifactsIfNeeded(
        uploadAttempted: uploadAttempted,
        artifactRevision: artifactRevision,
      );
      throw mappedError;
    } on StorageException catch (error) {
      final mappedError = _mapStorageError(error);
      await _discardUploadedArtifactsIfNeeded(
        uploadAttempted: uploadAttempted,
        artifactRevision: artifactRevision,
      );
      throw mappedError;
    }
  }

  @override
  Future<void> deleteTodayCard({required int expectedRevision}) async {
    _ensureSupabaseConfigured();

    try {
      await Supabase.instance.client
          .rpc(
            'delete_today_story_loop_card',
            params: {'expected_revision': expectedRevision},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  StorageFileApi get _bucket =>
      Supabase.instance.client.storage.from(_bucketId);

  void _ensureSupabaseConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.configMissing,
      );
    }
  }

  void _validateDraft(StoryCardDraft draft) {
    if (!draft.hasContent) {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.contentRequired,
      );
    }

    if (draft.scene.textLayers.length > storyCardMaxTextLayers ||
        draft.scene.textCharacterCount > storyCardMaxTextCharacters ||
        draft.scene.textLayers.any(
          (layer) => layer.text.characters.length >
              storyCardMaxTextCharactersPerLayer,
        )) {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.invalidTextContent,
      );
    }
  }

  Future<void> _discardUploadedArtifactsIfNeeded({
    required bool uploadAttempted,
    required String artifactRevision,
  }) async {
    if (!uploadAttempted) {
      return;
    }

    try {
      await Supabase.instance.client
          .rpc(
            'discard_uploaded_story_loop_card_artifacts',
            params: {'requested_artifact_revision': artifactRevision},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } catch (_) {
    }
  }

  Map<String, dynamic>? _asOptionalRow(Object? data) {
    if (data == null) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List) {
      if (data.isEmpty) {
        return null;
      }

      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw const StoryLoopWriteRepositoryException(
      StoryLoopWriteFailureReason.unknown,
    );
  }

  Map<String, dynamic> _asRow(Object? data) {
    final row = _asOptionalRow(data);
    if (row != null) {
      return row;
    }

    throw const StoryLoopWriteRepositoryException(
      StoryLoopWriteFailureReason.unknown,
    );
  }

  int _toInt(Object? value) => (value as num?)?.toInt() ?? 0;

  StoryLoopWriteRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return StoryLoopWriteRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  StoryLoopWriteRepositoryException _mapStorageError(StorageException error) {
    return StoryLoopWriteRepositoryException(
      StoryLoopWriteFailureReason.storage,
      error.message,
    );
  }

  StoryLoopWriteFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => StoryLoopWriteFailureReason.authRequired,
      'active_couple_required' =>
        StoryLoopWriteFailureReason.activeCoupleRequired,
      'relationship_date_required' =>
        StoryLoopWriteFailureReason.relationshipDateRequired,
      'story_not_ready' => StoryLoopWriteFailureReason.storyNotReady,
      'story_card_content_required' => StoryLoopWriteFailureReason.contentRequired,
      'invalid_story_card_text_content' =>
        StoryLoopWriteFailureReason.invalidTextContent,
      'story_card_locked' => StoryLoopWriteFailureReason.cardLocked,
      'story_card_revision_required' =>
        StoryLoopWriteFailureReason.revisionRequired,
      'story_card_revision_conflict' =>
        StoryLoopWriteFailureReason.revisionConflict,
      'story_card_not_found' => StoryLoopWriteFailureReason.cardNotFound,
      'question_pool_empty' => StoryLoopWriteFailureReason.questionPoolEmpty,
      _ => StoryLoopWriteFailureReason.unknown,
    };
  }
}

class _StoryCardArtifactPaths {
  const _StoryCardArtifactPaths({
    required this.coupleId,
    required this.coupleDate,
    required this.userId,
    required this.artifactRevision,
  });

  final String coupleId;
  final DateTime coupleDate;
  final String userId;
  final String artifactRevision;

  String get _prefix {
    final year = coupleDate.year.toString().padLeft(4, '0');
    final month = coupleDate.month.toString().padLeft(2, '0');
    final day = coupleDate.day.toString().padLeft(2, '0');
    return '$coupleId/loops/$year-$month-$day/$userId/$artifactRevision';
  }

  String get previewPath => '$_prefix/preview.png';

  String get sceneDataPath => '$_prefix/scene.json';

  String get backgroundImagePath => '$_prefix/background.jpg';
}
