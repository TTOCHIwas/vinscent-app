import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../profile/application/profile_controller.dart';
import '../../recordings/application/recording_capture_launch_request.dart';
import '../../story_loops/application/today_story_loop_summary_provider.dart';
import 'home_widget_launch_policy.dart';

final homeWidgetLaunchCoordinatorProvider =
    Provider<HomeWidgetLaunchCoordinator>((ref) {
      return HomeWidgetLaunchCoordinator(ref);
    });

class HomeWidgetLaunchCoordinator {
  const HomeWidgetLaunchCoordinator(this._ref);

  final Ref _ref;

  Stream<Uri?> get widgetClicks => HomeWidget.widgetClicked;

  Future<Uri?> initiallyLaunchedFromWidget() {
    return HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  Future<String?> resolveTarget(Uri? uri) async {
    final action = HomeWidgetLaunchAction.fromUri(uri);
    if (action == null) {
      return null;
    }
    if (action == HomeWidgetLaunchAction.record) {
      _ref.read(recordingCaptureLaunchRequestProvider.notifier).request();
      return HomeWidgetCardLaunchPolicy.homeLocation;
    }

    _ref.invalidate(todayStoryLoopSummaryProvider);
    final profile = await _ref.read(profileControllerProvider.future);
    final state = await _ref.read(todayStoryLoopSummaryProvider.future);
    return HomeWidgetCardLaunchPolicy.resolve(
      state: state,
      currentUserId: profile?.id,
    );
  }
}
