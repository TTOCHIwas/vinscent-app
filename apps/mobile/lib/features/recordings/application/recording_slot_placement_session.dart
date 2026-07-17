import 'package:flutter_riverpod/flutter_riverpod.dart';

final recordingSlotPlacementSessionProvider =
    NotifierProvider<RecordingSlotPlacementSessionController, String?>(
      RecordingSlotPlacementSessionController.new,
    );

class RecordingSlotPlacementSessionController extends Notifier<String?> {
  @override
  String? build() => null;

  void begin(String slotId) {
    state = slotId;
  }

  String? consume() {
    final slotId = state;
    state = null;
    return slotId;
  }

  void clear() {
    state = null;
  }
}
