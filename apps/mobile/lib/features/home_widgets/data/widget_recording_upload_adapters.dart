import 'dart:io';
import 'dart:typed_data';

import '../../couple/data/couple_repository.dart';
import '../../recordings/data/couple_recording_failure.dart';
import '../../recordings/data/couple_recording_repository_contract.dart';
import '../application/home_widget_synchronizer.dart';
import '../application/widget_recording_upload_task.dart';
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
  Future<void> upload(
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

    await _recordingRepository.uploadCurrentRecording(
      coupleId: couple.id,
      audioBytes: bytes,
      durationMs: durationMs,
      recordingId: recordingId,
      resumeExistingUpload: recordingId != null,
    );
  }
}

class HomeWidgetRecordingPlaybackCache implements WidgetRecordingPlaybackCache {
  const HomeWidgetRecordingPlaybackCache({required HomeWidgetStore store})
    : _store = store;

  final HomeWidgetStore _store;

  @override
  Future<void> replace(Uint8List bytes) async {
    await _store.saveFile(
      key: HomeWidgetStorage.recordingAudioPathKey,
      bytes: bytes,
      extension: 'm4a',
    );
    await _store.remove(HomeWidgetStorage.recordingAudioVersionKey);
    await _store.refreshWidget(HomeWidgetStorage.characterTarget);
  }
}
