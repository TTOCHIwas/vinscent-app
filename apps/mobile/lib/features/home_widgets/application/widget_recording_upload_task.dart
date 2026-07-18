import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../couple/data/couple_failure.dart';
import '../../couple/data/couple_repository.dart';
import '../../recordings/data/couple_recording_failure.dart';
import '../../recordings/data/couple_recording_repository.dart';
import '../data/home_widget_platform_store.dart';
import '../data/home_widget_snapshot.dart';
import 'home_widget_synchronizer.dart';

const widgetRecordingMaximumDurationMs = 15000;
const widgetRecordingMaximumBytes = 4 * 1024 * 1024;

class WidgetRecordingUploadRequest {
  const WidgetRecordingUploadRequest({
    required this.filePath,
    required this.durationMs,
    this.recordingId,
  });

  factory WidgetRecordingUploadRequest.fromArguments(Object? arguments) {
    if (arguments is! Map) {
      throw const FormatException('Widget recording arguments are missing.');
    }

    final filePath = arguments['filePath'];
    final durationMs = arguments['durationMs'];
    final recordingId = arguments['recordingId'];
    if (filePath is! String || filePath.trim().isEmpty) {
      throw const FormatException('Widget recording path is invalid.');
    }
    if (durationMs is! int ||
        durationMs < 1 ||
        durationMs > widgetRecordingMaximumDurationMs) {
      throw const FormatException('Widget recording duration is invalid.');
    }
    if (recordingId != null &&
        (recordingId is! String || recordingId.trim().isEmpty)) {
      throw const FormatException('Widget recording id is invalid.');
    }

    return WidgetRecordingUploadRequest(
      filePath: filePath,
      durationMs: durationMs,
      recordingId: recordingId as String?,
    );
  }

  final String filePath;
  final int durationMs;
  final String? recordingId;
}

abstract interface class WidgetRecordingDraftReader {
  Future<Uint8List> read(String filePath);
}

abstract interface class WidgetRecordingUploadGateway {
  Future<void> upload(
    Uint8List bytes, {
    required int durationMs,
    String? recordingId,
  });
}

abstract interface class WidgetRecordingPlaybackCache {
  Future<void> replace(Uint8List bytes);
}

class WidgetRecordingUploadTask {
  const WidgetRecordingUploadTask({
    required WidgetRecordingDraftReader draftReader,
    required WidgetRecordingUploadGateway uploadGateway,
    required WidgetRecordingPlaybackCache playbackCache,
  }) : _draftReader = draftReader,
       _uploadGateway = uploadGateway,
       _playbackCache = playbackCache;

  final WidgetRecordingDraftReader _draftReader;
  final WidgetRecordingUploadGateway _uploadGateway;
  final WidgetRecordingPlaybackCache _playbackCache;

  Future<void> execute(WidgetRecordingUploadRequest request) async {
    final bytes = await _draftReader.read(request.filePath);
    await _uploadGateway.upload(
      bytes,
      durationMs: request.durationMs,
      recordingId: request.recordingId,
    );
    await _replacePlaybackCacheBestEffort(bytes);
  }

  Future<void> _replacePlaybackCacheBestEffort(Uint8List bytes) async {
    try {
      await _playbackCache.replace(bytes);
    } catch (_) {}
  }
}

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
    await _store.updateAndroidWidget(
      HomeWidgetStorage.characterAndroidProvider,
    );
  }
}

bool isRetryableWidgetRecordingUploadError(Object error) {
  if (error is TimeoutException || error is SocketException) {
    return true;
  }
  if (error is CoupleRecordingRepositoryException) {
    return switch (error.reason) {
      CoupleRecordingFailureReason.requestTimeout ||
      CoupleRecordingFailureReason.storage ||
      CoupleRecordingFailureReason.unknown => true,
      _ => false,
    };
  }
  if (error is CoupleRepositoryException) {
    return error.reason == CoupleFailureReason.unknown;
  }
  return false;
}

WidgetRecordingUploadTask createWidgetRecordingUploadTask() {
  return WidgetRecordingUploadTask(
    draftReader: const FileWidgetRecordingDraftReader(),
    uploadGateway: const SupabaseWidgetRecordingUploadGateway(
      coupleRepository: SupabaseCoupleRepository(),
      recordingRepository: SupabaseCoupleRecordingRepository(),
    ),
    playbackCache: const HomeWidgetRecordingPlaybackCache(
      store: PluginHomeWidgetStore(),
    ),
  );
}
