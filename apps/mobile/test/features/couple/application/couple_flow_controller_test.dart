import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_flow_controller.dart';

void main() {
  test('uses app date when validating relationship start date', () {
    final container = ProviderContainer(
      overrides: [
        todayControllerProvider.overrideWithBuild(
          (ref, notifier) => DateTime(2026, 5, 31),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(coupleFlowControllerProvider.notifier);

    controller.updateRelationshipStartDate(DateTime(2026, 6, 1));
    expect(
      container.read(coupleFlowControllerProvider).relationshipStartDate,
      isNull,
    );

    controller.updateRelationshipStartDate(DateTime(2026, 5, 31, 23, 59));
    expect(
      container.read(coupleFlowControllerProvider).relationshipStartDate,
      DateTime(2026, 5, 31),
    );
  });
}
