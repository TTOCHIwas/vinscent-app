import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_download_service.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_detail_overlay.dart';

void main() {
  testWidgets('places the card download action to the left of close', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: _OverlayLauncher(),
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

  testWidgets('downloads the selected card without closing the overlay', (
    tester,
  ) async {
    final downloader = _FakeStoryCardDownloader();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storyCardDownloaderProvider.overrideWithValue(downloader),
        ],
        child: const MaterialApp(
          home: _OverlayLauncher(),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('story-card-detail-download')),
    );
    await tester.pumpAndSettle();

    expect(downloader.cardIds, ['card-1']);
    expect(find.byKey(const Key('story-card-detail-overlay')), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

class _OverlayLauncher extends StatelessWidget {
  const _OverlayLauncher();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showStoryCardDetailOverlay(
        context: context,
        cardId: 'card-1',
        previewUrl: null,
      ),
      child: const Text('open'),
    );
  }
}

class _FakeStoryCardDownloader implements StoryCardDownloader {
  final cardIds = <String>[];

  @override
  Future<void> download(String cardId) async {
    cardIds.add(cardId);
  }
}
