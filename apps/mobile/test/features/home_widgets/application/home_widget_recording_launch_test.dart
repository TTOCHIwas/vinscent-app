import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_launch_coordinator.dart';

void main() {
  test('legacy record widget launch only returns to home', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final target = await container
        .read(homeWidgetLaunchCoordinatorProvider)
        .resolveTarget(Uri.parse('vinscent://widget/record?homeWidget'));

    expect(target, '/home');
  });
}
