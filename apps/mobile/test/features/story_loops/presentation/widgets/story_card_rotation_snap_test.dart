import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_rotation_snap.dart';

void main() {
  group('StoryCardRotationSnapController', () {
    test('4도 이내에서 가장 가까운 직각으로 스냅한다', () {
      final controller = StoryCardRotationSnapController()..begin(0.2);

      final result = controller.resolve(_degrees(88));

      expect(result.angle, closeTo(math.pi / 2, 0.0001));
      expect(result.isSnapped, isTrue);
      expect(result.didSnap, isTrue);
    });

    test('스냅 후 7도 이내에서는 잠금을 유지해 경계 떨림을 막는다', () {
      final controller = StoryCardRotationSnapController()..begin(0.2);

      controller.resolve(_degrees(88));
      final held = controller.resolve(_degrees(96));
      final released = controller.resolve(_degrees(98));

      expect(held.angle, closeTo(math.pi / 2, 0.0001));
      expect(held.isSnapped, isTrue);
      expect(released.angle, closeTo(_degrees(98), 0.0001));
      expect(released.isSnapped, isFalse);
    });

    test('360도 근처에서는 0도로 정규화한다', () {
      final controller = StoryCardRotationSnapController()
        ..begin(_degrees(350));

      final result = controller.resolve(_degrees(359));

      expect(result.angle, closeTo(0, 0.0001));
      expect(result.isSnapped, isTrue);
    });
  });
}

double _degrees(double value) => value * math.pi / 180;
