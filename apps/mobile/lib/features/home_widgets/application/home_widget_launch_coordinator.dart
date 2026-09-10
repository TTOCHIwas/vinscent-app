import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'home_widget_launch_policy.dart';

final homeWidgetLaunchCoordinatorProvider =
    Provider<HomeWidgetLaunchCoordinator>((ref) {
      return const HomeWidgetLaunchCoordinator();
    });

class HomeWidgetLaunchCoordinator {
  const HomeWidgetLaunchCoordinator();

  Stream<Uri?> get widgetClicks => HomeWidget.widgetClicked;

  Future<Uri?> initiallyLaunchedFromWidget() {
    return HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  Future<String?> resolveTarget(Uri? uri) async {
    final action = HomeWidgetLaunchAction.fromUri(uri);
    if (action == null) {
      return null;
    }
    return HomeWidgetCardLaunchPolicy.resolve();
  }
}
