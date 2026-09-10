import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_launch_coordinator.dart';

void main() {
  test(
    'card and legacy record widget launches return directly to home',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final path in ['card', 'record']) {
        final target = await container
            .read(homeWidgetLaunchCoordinatorProvider)
            .resolveTarget(Uri.parse('vinscent://widget/$path?homeWidget'));
        expect(target, '/home');
      }
    },
  );
}
