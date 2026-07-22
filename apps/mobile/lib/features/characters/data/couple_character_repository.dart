import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import 'couple_character.dart';
import 'couple_character_failure.dart';

final coupleCharacterRepositoryProvider = Provider<CoupleCharacterRepository>((
  ref,
) {
  return const SupabaseCoupleCharacterRepository();
});

abstract interface class CoupleCharacterRepository {
  Future<CoupleCharacter?> fetchCurrentCharacter();

  Future<String?> fetchDrawingData(CoupleCharacter character);

  Future<CoupleCharacter> saveCharacter({
    required String coupleId,
    required Uint8List imageBytes,
    required String drawingDataJson,
  });
}

class SupabaseCoupleCharacterRepository implements CoupleCharacterRepository {
  const SupabaseCoupleCharacterRepository();

  static const _signedUrlExpiresInSeconds = 60 * 60;

  @override
  Future<CoupleCharacter?> fetchCurrentCharacter() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleCharacterRepositoryException(
        CoupleCharacterFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client
          .rpc('get_couple_character')
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asOptionalRow(data);

      if (row == null) {
        return null;
      }

      final imageUrl = await _createSignedUrl(row['image_path'] as String);
      return CoupleCharacter.fromJson(row, imageUrl: imageUrl);
    } on TimeoutException {
      throw const CoupleCharacterRepositoryException(
        CoupleCharacterFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on StorageException catch (error) {
      throw _mapStorageError(error);
    }
  }

  @override
  Future<String?> fetchDrawingData(CoupleCharacter character) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleCharacterRepositoryException(
        CoupleCharacterFailureReason.configMissing,
      );
    }

    try {
      final bytes = await _bucket
          .download(character.drawingDataPath)
          .timeout(AppConfig.supabaseRpcTimeout);

      return utf8.decode(bytes);
    } on TimeoutException {
      throw const CoupleCharacterRepositoryException(
        CoupleCharacterFailureReason.requestTimeout,
      );
    } on StorageException catch (error) {
      if (error.statusCode == '404') {
        return null;
      }

      throw _mapStorageError(error);
    }
  }

  @override
  Future<CoupleCharacter> saveCharacter({
    required String coupleId,
    required Uint8List imageBytes,
    required String drawingDataJson,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleCharacterRepositoryException(
        CoupleCharacterFailureReason.configMissing,
      );
    }

    final artifactRevision = const Uuid().v4();
    final imagePath = CoupleCharacterStoragePaths.imageRevisionPathFor(
      coupleId,
      artifactRevision,
    );
    final drawingDataPath =
        CoupleCharacterStoragePaths.drawingDataRevisionPathFor(
          coupleId,
          artifactRevision,
        );
    final drawingDataBytes = Uint8List.fromList(utf8.encode(drawingDataJson));
    var uploadAttempted = false;

    try {
      uploadAttempted = true;
      await _uploadArtifact(
        path: imagePath,
        bytes: imageBytes,
        contentType: 'image/png',
      );
      await _uploadArtifact(
        path: drawingDataPath,
        bytes: drawingDataBytes,
        contentType: 'application/json',
      );

      final data = await _finalizeCharacter(
        imagePath: imagePath,
        drawingDataPath: drawingDataPath,
      );
      final row = _asRow(data);
      final imageUrl = await _createSignedUrl(row['image_path'] as String);

      return CoupleCharacter.fromJson(row, imageUrl: imageUrl);
    } on TimeoutException {
      final finalizedCharacter = await _tryFetchFinalizedCharacter(
        imagePath: imagePath,
        drawingDataPath: drawingDataPath,
      );
      if (finalizedCharacter != null) {
        return finalizedCharacter;
      }

      throw const CoupleCharacterRepositoryException(
        CoupleCharacterFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      await _discardUploadedRevisionIfNeeded(
        uploadAttempted: uploadAttempted,
        artifactRevision: artifactRevision,
      );
      throw _mapPostgrestError(error);
    } on StorageException catch (error) {
      await _discardUploadedRevisionIfNeeded(
        uploadAttempted: uploadAttempted,
        artifactRevision: artifactRevision,
      );
      throw _mapStorageError(error);
    }
  }

  StorageFileApi get _bucket {
    return Supabase.instance.client.storage.from(
      CoupleCharacterStoragePaths.bucketId,
    );
  }

  Future<String> _createSignedUrl(String path) {
    return _bucket
        .createSignedUrl(path, _signedUrlExpiresInSeconds)
        .timeout(AppConfig.supabaseRpcTimeout);
  }

  Future<void> _uploadArtifact({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        await _bucket
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: contentType,
                cacheControl: '31536000',
              ),
            )
            .timeout(AppConfig.supabaseRpcTimeout);
        return;
      } on TimeoutException {
        if (attempt == 1) {
          rethrow;
        }
      } on StorageException catch (error) {
        if (attempt == 1 && _isDuplicateUpload(error)) {
          return;
        }
        rethrow;
      }
    }
  }

  Future<Object?> _finalizeCharacter({
    required String imagePath,
    required String drawingDataPath,
  }) async {
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await Supabase.instance.client
            .rpc(
              'upsert_couple_character',
              params: {
                'character_image_path': imagePath,
                'character_drawing_data_path': drawingDataPath,
              },
            )
            .timeout(AppConfig.supabaseRpcTimeout);
      } on TimeoutException {
        if (attempt == 1) {
          rethrow;
        }
      }
    }

    throw StateError('Character finalization did not complete.');
  }

  Future<CoupleCharacter?> _tryFetchFinalizedCharacter({
    required String imagePath,
    required String drawingDataPath,
  }) async {
    try {
      final data = await Supabase.instance.client
          .rpc('get_couple_character')
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asOptionalRow(data);
      if (row == null ||
          row['image_path'] != imagePath ||
          row['drawing_data_path'] != drawingDataPath) {
        return null;
      }

      final imageUrl = await _createSignedUrl(imagePath);
      return CoupleCharacter.fromJson(row, imageUrl: imageUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> _discardUploadedRevisionIfNeeded({
    required bool uploadAttempted,
    required String artifactRevision,
  }) async {
    if (!uploadAttempted) {
      return;
    }

    try {
      await Supabase.instance.client
          .rpc(
            'discard_uploaded_couple_character',
            params: {'requested_artifact_revision': artifactRevision},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } catch (_) {}
  }

  bool _isDuplicateUpload(StorageException error) {
    final message = error.message.toLowerCase();
    return error.statusCode == '409' ||
        message.contains('duplicate') ||
        message.contains('already exists');
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

    throw const CoupleCharacterRepositoryException(
      CoupleCharacterFailureReason.unknown,
    );
  }

  Map<String, dynamic> _asRow(Object? data) {
    final row = _asOptionalRow(data);
    if (row != null) {
      return row;
    }

    throw const CoupleCharacterRepositoryException(
      CoupleCharacterFailureReason.unknown,
    );
  }

  CoupleCharacterRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return CoupleCharacterRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  CoupleCharacterRepositoryException _mapStorageError(StorageException error) {
    return CoupleCharacterRepositoryException(
      CoupleCharacterFailureReason.storage,
      error.message,
    );
  }

  CoupleCharacterFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => CoupleCharacterFailureReason.authRequired,
      'active_couple_required' =>
        CoupleCharacterFailureReason.activeCoupleRequired,
      'initial_setup_owner_required' =>
        CoupleCharacterFailureReason.initialSetupOwnerRequired,
      'relationship_date_required' =>
        CoupleCharacterFailureReason.relationshipDateRequired,
      'invalid_character_path' => CoupleCharacterFailureReason.invalidPath,
      'character_artifact_missing' => CoupleCharacterFailureReason.storage,
      _ => CoupleCharacterFailureReason.unknown,
    };
  }
}
