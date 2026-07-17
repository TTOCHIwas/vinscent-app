import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/home_recording_placement_geometry.dart';
import 'package:vinscent/features/recordings/application/recording_slot_placement_session.dart';

void main() {
  const canvasSize = Size(336, 620);
  const itemSize = 48.0;
  final geometry = HomeRecordingPlacementGeometry(
    canvasSize: canvasSize,
    itemSize: itemSize,
    forbiddenRects: const [
      Rect.fromLTWH(0, 0, 336, 340),
      Rect.fromLTWH(59, 356, 218, 218),
    ],
  );

  test('resolves a requested center outside card and character regions', () {
    final resolved = geometry.resolve(const Offset(168, 465));

    expect(resolved, isNotNull);
    expect(geometry.isAllowed(resolved!), isTrue);
    expect(resolved.dx, isNot(closeTo(168, 1)));
  });

  test('normalizes and restores a valid center across viewport sizes', () {
    final center = geometry.resolve(const Offset(30, 420))!;
    final normalized = geometry.normalize(center);
    final restored = geometry.denormalize(normalized);

    expect(normalized.dx, inInclusiveRange(0, 1));
    expect(normalized.dy, inInclusiveRange(0, 1));
    expect(restored.dx, closeTo(center.dx, 0.001));
    expect(restored.dy, closeTo(center.dy, 0.001));
  });

  test('finds distinct default positions for four home artworks', () {
    final occupied = <Offset>[];

    for (var index = 0; index < 4; index++) {
      final position = geometry.findDefaultPosition(occupied: occupied);
      expect(position, isNotNull);
      expect(geometry.isAllowed(position!), isTrue);
      occupied.add(position);
    }

    expect(occupied.toSet(), hasLength(4));
  });

  test('placement session is consumed only once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      recordingSlotPlacementSessionProvider.notifier,
    );

    notifier.begin('slot-1');

    expect(container.read(recordingSlotPlacementSessionProvider), 'slot-1');
    expect(notifier.consume(), 'slot-1');
    expect(notifier.consume(), isNull);
  });
}
