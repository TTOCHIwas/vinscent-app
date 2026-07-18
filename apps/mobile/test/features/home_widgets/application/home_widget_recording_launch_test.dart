import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_launch_coordinator.dart';
import 'package:vinscent/features/recordings/application/recording_capture_launch_request.dart';

void main() {
  test('record widget launch queues one consumable capture request', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final target = await container
        .read(homeWidgetLaunchCoordinatorProvider)
        .resolveTarget(Uri.parse('vinscent://widget/record?homeWidget'));

    expect(target, '/home');
    final requestId = container.read(recordingCaptureLaunchRequestProvider);
    expect(requestId, isNotNull);

    final controller = container.read(
      recordingCaptureLaunchRequestProvider.notifier,
    );
    expect(controller.consume(requestId!), isTrue);
    expect(controller.consume(requestId), isFalse);
    expect(container.read(recordingCaptureLaunchRequestProvider), isNull);
  });
}
