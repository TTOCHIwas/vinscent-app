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

  List<CoupleRecordingSlot> get placedSlots {
    final slots = savedSlots
        .where((slot) => slot.placement != null)
        .toList(growable: true);
    slots.sort((left, right) {
      final zOrder = left.placement!.zIndex.compareTo(right.placement!.zIndex);
      return zOrder != 0 ? zOrder : left.slotIndex.compareTo(right.slotIndex);
    });
    return List.unmodifiable(slots);
  }
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

class CoupleRecordingSlotSaveResult {
  const CoupleRecordingSlotSaveResult({
    required this.slotId,
    required this.slotIndex,
    required this.slotRevision,
  });

  factory CoupleRecordingSlotSaveResult.fromJson(Map<String, dynamic> json) {
    return CoupleRecordingSlotSaveResult(
      slotId: json['slot_id'] as String,
      slotIndex: json['slot_index'] as int,
      slotRevision: json['slot_revision'] as int,
    );
  }

  final String slotId;
  final int slotIndex;
  final int slotRevision;
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
    this.artwork,
    this.placement,
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
  final CoupleRecordingSlotArtwork? artwork;
  final CoupleRecordingSlotPlacement? placement;

  Duration get duration => Duration(milliseconds: durationMs);
}

class CoupleRecordingSlotArtwork {
  const CoupleRecordingSlotArtwork({
    required this.previewPath,
    required this.previewUrl,
    required this.drawingDataPath,
    required this.revision,
  });

  final String previewPath;
  final String previewUrl;
  final String drawingDataPath;
  final int revision;
}

class CoupleRecordingSlotPlacement {
  const CoupleRecordingSlotPlacement({
    required this.normalizedX,
    required this.normalizedY,
    required this.revision,
    this.zIndex = 0,
  });

  final double normalizedX;
  final double normalizedY;
  final int revision;
  final int zIndex;
}
