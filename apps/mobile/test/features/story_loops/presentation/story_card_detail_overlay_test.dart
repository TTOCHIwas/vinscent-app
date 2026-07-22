import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_detail_overlay.dart';

void main() {
  testWidgets('places the card download action to the left of close', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showStoryCardDetailOverlay(
              context: context,
              cardId: 'card-1',
              previewUrl: null,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final download = find.byKey(
      const Key('story-card-detail-download'),
    );
    final close = find.byKey(const Key('story-card-detail-close'));

    expect(download, findsOneWidget);
    expect(close, findsOneWidget);
    expect(tester.getCenter(download).dy, tester.getCenter(close).dy);
    expect(tester.getCenter(download).dx, lessThan(tester.getCenter(close).dx));
  });
}
