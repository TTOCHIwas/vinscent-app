import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import 'couple_calendar_event_artwork_path.dart';
import 'couple_calendar_event_data_gateways.dart';
import 'couple_calendar_event_failure.dart';

class SupabaseCoupleCalendarEventArtworkStore
    implements CoupleCalendarEventArtworkStore {
  const SupabaseCoupleCalendarEventArtworkStore();

  static const _maxObjectBytes = 256 * 1024;

  @override
  Future<Uint8List> fetchDrawingData(String path) async {
    _ensureConfigured();

    try {
      return await _bucket
          .download(path)
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.requestTimeout,
      );
    } on StorageException catch (error) {
      throw CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.storage,
        error.message,
      );
    }
  }

  @override
  Future<String> uploadArtwork({
    required String coupleId,
    required String eventId,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) async {
    _ensureConfigured();
    if (previewBytes.isEmpty ||
        drawingDataBytes.isEmpty ||
        previewBytes.length > _maxObjectBytes ||
        drawingDataBytes.length > _maxObjectBytes) {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.invalidArtwork,
      );
    }

    final artifactId = const Uuid().v4();
    final paths = CoupleCalendarEventArtworkPath(
      coupleId: coupleId,
      eventId: eventId,
      artifactId: artifactId,
    );

    try {
      await _bucket
          .uploadBinary(
            paths.previewPath,
            previewBytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/webp',
              cacheControl: '31536000',
            ),
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      await _bucket
          .uploadBinary(
            paths.drawingDataPath,
            drawingDataBytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'application/gzip',
              cacheControl: '31536000',
            ),
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      return artifactId;
    } on TimeoutException {
      await discardUploadedArtwork(
        eventId: eventId,
        artifactId: artifactId,
      );
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.requestTimeout,
      );
    } on StorageException catch (error) {
      await discardUploadedArtwork(
        eventId: eventId,
        artifactId: artifactId,
      );
      throw CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.storage,
        error.message,
      );
    } catch (_) {
      await discardUploadedArtwork(
        eventId: eventId,
        artifactId: artifactId,
      );
      rethrow;
    }
  }

  @override
  Future<void> discardUploadedArtwork({
    required String eventId,
    required String artifactId,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      return;
    }

    try {
      await Supabase.instance.client
          .rpc(
            'discard_uploaded_couple_calendar_event_artwork',
            params: {
              'requested_event_id': eventId,
              'requested_artwork_revision': artifactId,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[calendar] Failed to discard uploaded artwork: '
          'eventId=$eventId, artifactId=$artifactId, error=$error',
        );
      }
    }
  }

  StorageFileApi get _bucket => Supabase.instance.client.storage.from(
    CoupleCalendarEventArtworkPath.bucketId,
  );

  void _ensureConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.configMissing,
      );
    }
  }
}
