import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/home_recording_drag_session.dart';

void main() {
  test('starts a drag and brings the selected artwork to the front', () {
    final session = const HomeRecordingDragSession.idle().start(
      slotId: 'slot-1',
      position: const Offset(40, 60),
    );

    expect(session.frontSlotId, 'slot-1');
    expect(session.draggingSlotId, 'slot-1');
    expect(session.dragPosition, const Offset(40, 60));
    expect(session.isOverTrash, isFalse);
  });

  test('clamps drag movement and detects the expanded trash target', () {
    final session = const HomeRecordingDragSession.idle()
        .start(slotId: 'slot-1', position: const Offset(40, 40))
        .update(
          slotId: 'slot-1',
          delta: const Offset(200, 200),
          canvasSize: const Size(200, 200),
          itemSize: 80,
          trashRect: const Rect.fromLTWH(130, 130, 40, 40),
        );

    expect(session.dragPosition, const Offset(160, 160));
    expect(session.isOverTrash, isTrue);
  });

  test('ignores updates for an artwork that is not being dragged', () {
    final session = const HomeRecordingDragSession.idle().start(
      slotId: 'slot-1',
      position: const Offset(40, 40),
    );

    final unchanged = session.update(
      slotId: 'slot-2',
      delta: const Offset(20, 20),
      canvasSize: const Size(200, 200),
      itemSize: 80,
      trashRect: Rect.zero,
    );

    expect(unchanged, same(session));
  });

  test('ending keeps z-order until persistence finishes', () {
    final session = const HomeRecordingDragSession.idle().start(
      slotId: 'slot-1',
      position: const Offset(40, 40),
    );

    final ended = session.end(slotId: 'slot-1');

    expect(ended.frontSlotId, 'slot-1');
    expect(ended.draggingSlotId, isNull);
    expect(ended.dragPosition, isNull);
    expect(ended.isOverTrash, isFalse);
  });

  test('cancelling clears both drag and temporary z-order state', () {
    final session = const HomeRecordingDragSession.idle().start(
      slotId: 'slot-1',
      position: const Offset(40, 40),
    );

    expect(session.cancel(), const HomeRecordingDragSession.idle());
  });
}
