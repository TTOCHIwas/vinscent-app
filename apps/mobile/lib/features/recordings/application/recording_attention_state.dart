import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/couple_recording.dart';
import 'couple_recording_overview_controller.dart';

class RecordingAttentionState {
  const RecordingAttentionState({
    required this.hasUnseenCurrentRecording,
    required this.unseenSlotIds,
  });

  const RecordingAttentionState.empty()
    : hasUnseenCurrentRecording = false,
      unseenSlotIds = const {};

  factory RecordingAttentionState.fromOverview(
    CoupleRecordingOverview? overview,
  ) {
    if (overview == null) {
      return const RecordingAttentionState.empty();
    }

    return RecordingAttentionState(
      hasUnseenCurrentRecording: overview.currentRecording?.isUnseen ?? false,
      unseenSlotIds: Set.unmodifiable(
        overview.savedSlots
            .where((slot) => slot.isUnseen)
            .map((slot) => slot.slotId),
      ),
    );
  }

  final bool hasUnseenCurrentRecording;
  final Set<String> unseenSlotIds;

  bool get hasUnread => hasUnseenCurrentRecording || unseenSlotIds.isNotEmpty;

  bool hasUnseenSlot(String slotId) => unseenSlotIds.contains(slotId);
}

final recordingAttentionStateProvider = Provider<RecordingAttentionState>((
  ref,
) {
  final overview = ref.watch(coupleRecordingOverviewControllerProvider);
  return RecordingAttentionState.fromOverview(overview.asData?.value);
});
