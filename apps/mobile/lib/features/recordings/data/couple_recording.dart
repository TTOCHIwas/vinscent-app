class CoupleRecordingOverview {
  const CoupleRecordingOverview({
    required this.slotLimit,
    required this.currentRecording,
    required this.savedSlots,
  });

  final int slotLimit;
  final CurrentCoupleRecording? currentRecording;
  final List<CoupleRecordingSlot> savedSlots;

  bool get hasUnlockedEmptySlot => savedSlots.length < slotLimit;
}

class CurrentCoupleRecording {
  const CurrentCoupleRecording({
    required this.recordingId,
    required this.senderUserId,
    required this.durationMs,
    required this.recordedAt,
    required this.revision,
    required this.updatedAt,
    required this.audioUrl,
  });

  final String recordingId;
  final String senderUserId;
  final int durationMs;
  final DateTime recordedAt;
  final int revision;
  final DateTime updatedAt;
  final String audioUrl;

  Duration get duration => Duration(milliseconds: durationMs);
}

class CoupleRecordingSlot {
  const CoupleRecordingSlot({
    required this.slotId,
    required this.slotIndex,
    required this.title,
    required this.recordingId,
    required this.senderUserId,
    required this.durationMs,
    required this.recordedAt,
    required this.slotRevision,
    required this.createdByUserId,
    required this.updatedByUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.audioUrl,
  });

  final String slotId;
  final int slotIndex;
  final String title;
  final String recordingId;
  final String senderUserId;
  final int durationMs;
  final DateTime recordedAt;
  final int slotRevision;
  final String? createdByUserId;
  final String? updatedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String audioUrl;

  Duration get duration => Duration(milliseconds: durationMs);
}
