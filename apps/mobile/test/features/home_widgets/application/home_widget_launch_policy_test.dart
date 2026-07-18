import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_launch_policy.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_summary.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary_state.dart';

import '../../../support/story_loop_fixtures.dart';

void main() {
  group('HomeWidgetLaunchAction', () {
    test('카드와 녹음 위젯 URI만 해석한다', () {
      expect(
        HomeWidgetLaunchAction.fromUri(
          Uri.parse('vinscent://widget/card?homeWidget'),
        ),
        HomeWidgetLaunchAction.card,
      );
      expect(
        HomeWidgetLaunchAction.fromUri(
          Uri.parse('vinscent://widget/record?homeWidget'),
        ),
        HomeWidgetLaunchAction.record,
      );
      expect(
        HomeWidgetLaunchAction.fromUri(Uri.parse('vinscent://other/card')),
        isNull,
      );
    });
  });

  group('HomeWidgetCardLaunchPolicy', () {
    test('오늘 내 카드가 없고 작성 가능하면 카드 작성으로 이동한다', () {
      final state = EmptyTodayStoryLoopSummaryState(
        summary: sampleTodaySummary(
          loopId: null,
          loopStatus: null,
          storyEditLocked: false,
          canEditStory: true,
          canAnswerQuestion: false,
          cardCount: 0,
          cards: const [],
          question: null,
        ),
      );

      expect(
        HomeWidgetCardLaunchPolicy.resolve(
          state: state,
          currentUserId: 'user-a',
        ),
        '/home/story',
      );
    });

    test('상대 카드만 있고 내 카드가 없으면 카드 작성이 우선한다', () {
      final state = LoadedTodayStoryLoopSummaryState(
        summary: sampleTodaySummary(
          storyEditLocked: false,
          canEditStory: true,
          canAnswerQuestion: false,
          cardCount: 1,
          cards: [samplePreviewCard(authorUserId: 'user-b')],
          question: null,
        ),
      );

      expect(
        HomeWidgetCardLaunchPolicy.resolve(
          state: state,
          currentUserId: 'user-a',
        ),
        '/home/story',
      );
    });

    test('질문에 아직 답하지 않았으면 답변 작성으로 이동한다', () {
      final state = LoadedTodayStoryLoopSummaryState(
        summary: sampleTodaySummary(
          question: StoryLoopQuestionSummary(
            question: sampleDailyQuestion(),
            myAnswerExists: false,
            partnerAnswerExists: true,
            answerCount: 1,
          ),
        ),
      );

      expect(
        HomeWidgetCardLaunchPolicy.resolve(
          state: state,
          currentUserId: 'user-a',
        ),
        '/home/question/edit',
      );
    });

    test('이미 답했거나 상태를 사용할 수 없으면 홈으로 이동한다', () {
      final answeredState = LoadedTodayStoryLoopSummaryState(
        summary: sampleTodaySummary(
          question: StoryLoopQuestionSummary(
            question: sampleDailyQuestion(),
            myAnswerExists: true,
            partnerAnswerExists: false,
            answerCount: 1,
          ),
        ),
      );

      expect(
        HomeWidgetCardLaunchPolicy.resolve(
          state: answeredState,
          currentUserId: 'user-a',
        ),
        '/home',
      );
      expect(
        HomeWidgetCardLaunchPolicy.resolve(
          state: const UnavailableTodayStoryLoopSummaryState(
            reason: TodayStoryLoopSummaryUnavailableReason.unavailable,
          ),
          currentUserId: 'user-a',
        ),
        '/home',
      );
    });
  });
}
