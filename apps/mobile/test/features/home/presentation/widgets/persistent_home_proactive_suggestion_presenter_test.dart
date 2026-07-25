import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home/presentation/widgets/persistent_home_proactive_suggestion_presenter.dart';

void main() {
  testWidgets('keeps an approved suggestion visible without a timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestHost(enabled: true, beforeShow: () async => true),
    );
    await tester.pump();

    expect(find.text(_suggestionText), findsOneWidget);

    await tester.pump(const Duration(hours: 1));

    expect(find.text(_suggestionText), findsOneWidget);
  });

  testWidgets('temporarily hides and restores an undismissed suggestion', (
    tester,
  ) async {
    var enabled = true;
    late StateSetter setHostState;
    var claimCount = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return _TestHost(
            enabled: enabled,
            beforeShow: () async {
              claimCount += 1;
              return true;
            },
          );
        },
      ),
    );
    await tester.pump();
    expect(find.text(_suggestionText), findsOneWidget);

    setHostState(() => enabled = false);
    await tester.pump();
    expect(find.text(_suggestionText), findsNothing);

    setHostState(() => enabled = true);
    await tester.pump();
    expect(find.text(_suggestionText), findsOneWidget);
    expect(claimCount, 1);
  });

  testWidgets('hides immediately when the user dismisses it', (tester) async {
    var dismissCount = 0;

    await tester.pumpWidget(
      _TestHost(
        enabled: true,
        beforeShow: () async => true,
        onDismissed: () async {
          dismissCount += 1;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('dismiss-suggestion')));
    await tester.pump();

    expect(find.text(_suggestionText), findsNothing);
    expect(dismissCount, 1);
  });

  testWidgets('starts fresh when the foreground presentation changes', (
    tester,
  ) async {
    var presentationId = 'suggestion-1:session-1';
    late StateSetter setHostState;
    var claimCount = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setHostState = setState;
          return _TestHost(
            presentationId: presentationId,
            enabled: true,
            beforeShow: () async {
              claimCount += 1;
              return true;
            },
          );
        },
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('dismiss-suggestion')));
    await tester.pump();
    expect(find.text(_suggestionText), findsNothing);

    setHostState(() {
      presentationId = 'suggestion-1:session-2';
    });
    await tester.pump();
    await tester.pump();

    expect(find.text(_suggestionText), findsOneWidget);
    expect(claimCount, 2);
  });

  testWidgets(
    'does not display a suggestion rejected by the impression guard',
    (tester) async {
      await tester.pumpWidget(
        _TestHost(enabled: true, beforeShow: () async => false),
      );
      await tester.pump();

      expect(find.text(_suggestionText), findsNothing);
    },
  );
}

const _suggestionText = '날이 괜찮다면 함께 걷다가 마음에 드는 장면을 카드로 남겨도 좋겠다';

class _TestHost extends StatelessWidget {
  const _TestHost({
    required this.enabled,
    required this.beforeShow,
    this.presentationId = 'suggestion-1:session-1',
    this.onDismissed,
  });

  final bool enabled;
  final Future<bool> Function() beforeShow;
  final String presentationId;
  final Future<void> Function()? onDismissed;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: PersistentHomeProactiveSuggestionPresenter(
        presentationId: presentationId,
        suggestionText: _suggestionText,
        enabled: enabled,
        beforeShow: beforeShow,
        onDismissed: onDismissed,
        builder: (text, dismiss) {
          if (text == null) {
            return const Text('hidden');
          }
          return GestureDetector(
            key: const Key('dismiss-suggestion'),
            onTap: dismiss,
            child: Text(text),
          );
        },
      ),
    );
  }
}
