import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/presentation/calendar_month_layout_metrics.dart';
import 'package:vinscent/features/calendar/presentation/calendar_viewport_motion_controller.dart';

void main() {
  group('CalendarViewportMotionController', () {
    test('absorbs the dead zone and resists viewport transition drags', () {
      final controller = CalendarViewportMotionController();
      controller.begin(
        startState: CalendarViewportState.standard,
        startedInDetail: false,
      );

      expect(controller.applyUserOffset(-16), 0);
      expect(controller.applyUserOffset(-24), closeTo(-6.4, 0.001));
      expect(controller.effectiveScrollDisplacement, 20);
      expect(controller.isViewportTransition, isTrue);
      expect(controller.shouldSuppressBallisticMotion, isTrue);
    });

    test('passes through gestures that start in the detail content', () {
      final controller = CalendarViewportMotionController();
      controller.begin(
        startState: CalendarViewportState.weekly,
        startedInDetail: true,
      );

      expect(controller.applyUserOffset(-32), -32);
      expect(controller.effectiveScrollDisplacement, 0);
      expect(controller.isViewportTransition, isFalse);
      expect(controller.shouldSuppressBallisticMotion, isFalse);
    });

    test('passes upward weekly gestures through to the detail content', () {
      final controller = CalendarViewportMotionController();
      controller.begin(
        startState: CalendarViewportState.weekly,
        startedInDetail: false,
      );

      expect(controller.applyUserOffset(-32), -32);
      expect(controller.isViewportTransition, isFalse);
      expect(controller.shouldSuppressBallisticMotion, isFalse);
    });

    test('resists downward weekly gestures toward the standard state', () {
      final controller = CalendarViewportMotionController();
      controller.begin(
        startState: CalendarViewportState.weekly,
        startedInDetail: false,
      );

      expect(controller.applyUserOffset(30), closeTo(3.2, 0.001));
      expect(controller.effectiveScrollDisplacement, -10);
      expect(controller.isViewportTransition, isTrue);
      expect(controller.shouldSuppressBallisticMotion, isTrue);
    });

    test('clears accumulated motion before the next gesture', () {
      final controller = CalendarViewportMotionController();
      controller.begin(
        startState: CalendarViewportState.standard,
        startedInDetail: false,
      );
      controller.applyUserOffset(-40);

      controller.clear();
      controller.begin(
        startState: CalendarViewportState.standard,
        startedInDetail: false,
      );

      expect(controller.applyUserOffset(-16), 0);
      expect(controller.effectiveScrollDisplacement, 0);
    });
  });
}
