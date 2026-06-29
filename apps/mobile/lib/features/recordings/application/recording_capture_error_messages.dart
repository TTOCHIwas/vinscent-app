import '../data/couple_recording_failure.dart';

String recordingCaptureErrorMessage(Object error) {
  if (error is CoupleRecordingRepositoryException) {
    return switch (error.reason) {
      CoupleRecordingFailureReason.requestTimeout =>
        '녹음 업로드가 지연되고 있어요. 다시 시도해 주세요.',
      CoupleRecordingFailureReason.currentRecordingRequired =>
        '현재 저장된 녹음이 없어요.',
      CoupleRecordingFailureReason.recordingFileMissing =>
        '저장을 완료하지 못했어요. 다시 시도해 주세요.',
      CoupleRecordingFailureReason.recordingSlotConflict =>
        '보관함이 다른 기기에서 변경됐어요. 화면을 새로고침한 뒤 다시 시도해 주세요.',
      CoupleRecordingFailureReason.recordingSlotLocked =>
        '먼저 슬롯을 열어 주세요.',
      CoupleRecordingFailureReason.recordingSlotLimitReached =>
        '더 이상 열 수 있는 슬롯이 없어요.',
      CoupleRecordingFailureReason.storage => '녹음 파일을 저장하지 못했어요.',
      _ => '녹음을 저장하지 못했어요.',
    };
  }

  return '녹음을 저장하지 못했어요.';
}
