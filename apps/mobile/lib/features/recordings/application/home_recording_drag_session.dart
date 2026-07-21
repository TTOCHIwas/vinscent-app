import 'dart:ui';

class HomeRecordingDragSession {
  const HomeRecordingDragSession.idle()
    : frontSlotId = null,
      draggingSlotId = null,
      dragPosition = null,
      isOverTrash = false;

  const HomeRecordingDragSession._({
    required this.frontSlotId,
    required this.draggingSlotId,
    required this.dragPosition,
    required this.isOverTrash,
  });

  final String? frontSlotId;
  final String? draggingSlotId;
  final Offset? dragPosition;
  final bool isOverTrash;

  HomeRecordingDragSession start({
    required String slotId,
    required Offset position,
  }) {
    return HomeRecordingDragSession._(
      frontSlotId: slotId,
      draggingSlotId: slotId,
      dragPosition: position,
      isOverTrash: false,
    );
  }

  HomeRecordingDragSession update({
    required String slotId,
    required Offset delta,
    required Size canvasSize,
    required double itemSize,
    required Rect trashRect,
  }) {
    final position = dragPosition;
    if (draggingSlotId != slotId || position == null) {
      return this;
    }

    final halfItem = itemSize / 2;
    final next = position + delta;
    final clamped = Offset(
      next.dx.clamp(halfItem, canvasSize.width - halfItem),
      next.dy.clamp(halfItem, canvasSize.height - halfItem),
    );
    return HomeRecordingDragSession._(
      frontSlotId: frontSlotId,
      draggingSlotId: draggingSlotId,
      dragPosition: clamped,
      isOverTrash: trashRect.inflate(12).contains(clamped),
    );
  }

  HomeRecordingDragSession end({required String slotId}) {
    if (draggingSlotId != slotId) {
      return this;
    }
    return HomeRecordingDragSession._(
      frontSlotId: frontSlotId,
      draggingSlotId: null,
      dragPosition: null,
      isOverTrash: false,
    );
  }

  HomeRecordingDragSession cancel() {
    if (draggingSlotId == null) {
      return this;
    }
    return const HomeRecordingDragSession.idle();
  }
}
