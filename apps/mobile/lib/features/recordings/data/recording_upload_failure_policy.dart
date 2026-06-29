import 'package:flutter/foundation.dart';

import 'couple_recording_failure.dart';

bool shouldDiscardUploadedRecording(
  CoupleRecordingRepositoryException error,
) {
  return switch (error.reason) {
    CoupleRecordingFailureReason.recordingFileMissing ||
    CoupleRecordingFailureReason.invalidRecordingPath => true,
    _ => false,
  };
}

void debugRecordingLog(String message) {
  if (kDebugMode) {
    debugPrint('[recording] $message');
  }
}
