import 'dart:io';
import 'dart:typed_data';

import '../../couple/data/couple_repository.dart';
import '../../recordings/data/couple_recording_failure.dart';
import '../../recordings/data/couple_recording_repository_contract.dart';
import '../../recordings/data/recording_id_generator.dart';
import '../application/home_widget_synchronizer.dart';
import '../application/widget_recording_upload_task.dart';
import 'home_widget_recording_cache_repository.dart';
import 'home_widget_snapshot.dart';

class FileWidgetRecordingDraftReader implements WidgetRecordingDraftReader {
  const FileWidgetRecordingDraftReader();

  @override
  Future<Uint8List> read(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const FormatException('Widget recording draft does not exist.');
    }

    final length = await file.length();
    if (length < 1 || length > widgetRecordingMaximumBytes) {
      throw const FormatException('Widget recording draft size is invalid.');
    }
    return file.readAsBytes();
  }
}

class SupabaseWidgetRecordingUploadGateway
    implements WidgetRecordingUploadGateway {
  const SupabaseWidgetRecordingUploadGateway({
    required CoupleRepository coupleRepository,
    required CoupleRecordingRepository recordingRepository,
  }) : _coupleRepository = coupleRepository,
       _recordingRepository = recordingRepository;

  final CoupleRepository _coupleRepository;
  final CoupleRecordingRepository _recordingRepository;

  @override
  Future<WidgetRecordingUploadReceipt> upload(
    Uint8List bytes, {
    required int durationMs,
    String? recordingId,
  }) async {
    final couple = await _coupleRepository.fetchCurrentCouple();
    if (couple == null || !couple.canEditSharedData) {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.activeCoupleRequired,
      );
    }

    final resolvedRecordingId = recordingId ?? generateRecordingId();
    await _recordingRepository.uploadCurrentRecording(
      coupleId: couple.id,
      audioBytes: bytes,
      durationMs: durationMs,
      recordingId: resolvedRecordingId,
      resumeExistingUpload: recordingId != null,
    );
    return WidgetRecordingUploadReceipt(
      coupleId: couple.id,
      recordingId: resolvedRecordingId,
    );
  }
}

class HomeWidgetRecordingPlaybackCache implements WidgetRecordingPlaybackCache {
  const HomeWidgetRecordingPlaybackCache({
    required HomeWidgetRecordingCacheRepository cacheRepository,
    required HomeWidgetStore store,
  }) : _cacheRepository = cacheRepository,
       _store = store;

  final HomeWidgetRecordingCacheRepository _cacheRepository;
  final HomeWidgetStore _store;

  @override
  Future<void> replace(
    Uint8List bytes,
    WidgetRecordingUploadReceipt receipt,
  ) async {
    await _cacheRepository.installVerified(
      coupleId: receipt.coupleId,
      recordingId: receipt.recordingId,
      revision: 0,
      bytes: bytes,
    );
    await _store.refreshWidget(HomeWidgetStorage.characterTarget);
  }
}
