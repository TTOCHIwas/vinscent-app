import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home/data/home_feedback_impression_store.dart';
import 'package:vinscent/features/home/presentation/widgets/transient_home_feedback_presenter.dart';

void main() {
  testWidgets('reports an impression only when feedback becomes visible', (
    tester,
  ) async {
    final store = _FakeImpressionStore();
    var shownCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeFeedbackImpressionStoreProvider.overrideWithValue(store),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TransientHomeFeedbackPresenter(
            userId: 'user-1',
            dailyQuestionId: 'suggestion-1:session-1',
            feedbackText: '하늘이 괜찮아 보이면 사진을 남겨도 예쁘겠다',
            visibleDuration: const Duration(seconds: 1),
            onShown: () => shownCount += 1,
            builder: (text, opacity) => Text(text ?? 'hidden'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('하늘이 괜찮아 보이면 사진을 남겨도 예쁘겠다'), findsOneWidget);
    expect(shownCount, 1);
    expect(store.markedQuestionIds, ['suggestion-1:session-1']);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(TransientHomeFeedbackPresenter.fadeDuration);
    expect(find.text('hidden'), findsOneWidget);
    expect(shownCount, 1);
  });

  testWidgets('does not report feedback already shown in the same session', (
    tester,
  ) async {
    final store = _FakeImpressionStore(
      shownQuestionIds: {'suggestion-1:session-1'},
    );
    var shownCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeFeedbackImpressionStoreProvider.overrideWithValue(store),
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: TransientHomeFeedbackPresenter(
            userId: 'user-1',
            dailyQuestionId: 'suggestion-1:session-1',
            feedbackText: '다시 보이면 안 되는 문구',
            onShown: () => shownCount += 1,
            builder: (text, opacity) => Text(text ?? 'hidden'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('hidden'), findsOneWidget);
    expect(shownCount, 0);
    expect(store.markedQuestionIds, isEmpty);
  });
}

class _FakeImpressionStore implements HomeFeedbackImpressionStore {
  _FakeImpressionStore({Set<String>? shownQuestionIds})
    : shownQuestionIds = shownQuestionIds ?? {};

  final Set<String> shownQuestionIds;
  final List<String> markedQuestionIds = [];

  @override
  Future<bool> hasShown({
    required String userId,
    required String dailyQuestionId,
  }) async {
    return shownQuestionIds.contains(dailyQuestionId);
  }

  @override
  Future<void> markShown({
    required String userId,
    required String dailyQuestionId,
  }) async {
    markedQuestionIds.add(dailyQuestionId);
    shownQuestionIds.add(dailyQuestionId);
  }
}
