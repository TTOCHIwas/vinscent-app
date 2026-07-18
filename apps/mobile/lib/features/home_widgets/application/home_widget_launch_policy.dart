import '../../couple/data/couple.dart';
import '../../story_loops/data/today_story_loop_summary.dart';
import '../../story_loops/data/today_story_loop_summary_state.dart';

enum HomeWidgetLaunchAction {
  card,
  record;

  static HomeWidgetLaunchAction? fromUri(Uri? uri) {
    if (uri == null ||
        uri.scheme != 'vinscent' ||
        uri.host != 'widget' ||
        !uri.queryParameters.containsKey('homeWidget')) {
      return null;
    }

    return switch (uri.path) {
      '/card' => HomeWidgetLaunchAction.card,
      '/record' => HomeWidgetLaunchAction.record,
      _ => null,
    };
  }
}

class HomeWidgetCardLaunchPolicy {
  const HomeWidgetCardLaunchPolicy._();

  static const homeLocation = '/home';
  static const storyEditorLocation = '/home/story';
  static const questionEditorLocation = '/home/question/edit';

  static String resolve({
    required TodayStoryLoopSummaryState state,
    required String? currentUserId,
  }) {
    final summary = switch (state) {
      LoadedTodayStoryLoopSummaryState(:final summary) => summary,
      EmptyTodayStoryLoopSummaryState(:final summary) => summary,
      UnavailableTodayStoryLoopSummaryState() => null,
    };
    if (summary == null || currentUserId == null) {
      return homeLocation;
    }

    if (_canCreateMyCard(summary, currentUserId)) {
      return storyEditorLocation;
    }

    final question = summary.question;
    if (summary.canAnswerQuestion &&
        question != null &&
        !question.myAnswerExists) {
      return questionEditorLocation;
    }

    return homeLocation;
  }

  static bool _canCreateMyCard(
    TodayStoryLoopSummary summary,
    String currentUserId,
  ) {
    if (summary.accessMode != CoupleAccessMode.active ||
        !summary.canEditStory) {
      return false;
    }

    return !summary.cards.any((card) => card.authorUserId == currentUserId);
  }
}
