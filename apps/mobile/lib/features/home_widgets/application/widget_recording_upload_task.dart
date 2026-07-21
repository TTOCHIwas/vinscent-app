import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../couple/data/couple_failure.dart';
import '../../recordings/data/couple_recording_failure.dart';

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
