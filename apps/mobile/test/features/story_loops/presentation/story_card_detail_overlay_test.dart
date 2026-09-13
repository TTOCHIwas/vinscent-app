import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/presentation/safety_report_sheet.dart';
import 'package:vinscent/features/story_loops/application/story_card_download_service.dart';
import 'package:vinscent/features/story_loops/application/today_story_card_stacks_provider.dart';
import 'package:vinscent/features/story_loops/data/story_card_stack_item.dart';
import 'package:vinscent/features/story_loops/data/story_card_stack_preview.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';
import 'package:vinscent/features/story_loops/data/story_loop_card_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_card_preview.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_interactive_viewport.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_stack_overlay.dart';

void main() {
  testWidgets('호출 화면이 지정한 카드를 공통 상세보기의 초기 카드로 연다', (tester) async {
    final items = [
      _item(id: 'card-1', minute: 1),
      _item(id: 'card-2', minute: 2),
    ];
    await _pumpOverlay(tester, items: items, initialCardId: 'card-1');

    await _open(tester);

    expect(find.byKey(const Key('story-card-stack-overlay')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('상대 카드의 공통 더보기에서 신고 시트를 연다', (tester) async {
    await _pumpOverlay(
      tester,
      items: [_item(id: 'card-1', minute: 1)],
      isMine: false,
    );

    await _open(tester);
    await tester.tap(find.byKey(const Key('story-card-stack-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('story-card-action-report-card-1')),
    );
    await tester.pumpAndSettle();

    final sheet = tester.widget<SafetyReportSheet>(
      find.byType(SafetyReportSheet),
    );
    expect(
      sheet.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.storyCard,
        id: 'card-1',
      ),
    );
  });

  testWidgets('공통 더보기에서 선택한 카드를 내려받고 상세보기는 유지한다', (tester) async {
    final downloader = _FakeStoryCardDownloader();
    await _pumpOverlay(
      tester,
      items: [_item(id: 'card-1', minute: 1)],
      downloader: downloader,
    );

    await _open(tester);
    await tester.tap(find.byKey(const Key('story-card-stack-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('story-card-action-download-card-1')),
    );
    await tester.pumpAndSettle();

    expect(downloader.cardIds, ['card-1']);
    expect(find.byKey(const Key('story-card-stack-overlay')), findsOneWidget);
    expect(find.text('카드를 갤러리에 저장했어요.'), findsOneWidget);
  });

  testWidgets('세로 네컷도 공통 상세보기의 상단과 하단 동작 영역을 침범하지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpOverlay(
      tester,
      items: [
        _item(id: 'card-1', minute: 1, cardType: StoryCardType.fourCutStrip),
      ],
    );

    await _open(tester);

    final card = tester.getRect(
      find.byKey(const Key('story-card-stack-card-1')),
    );
    final close = tester.getRect(
      find.byKey(const Key('story-card-stack-close')),
    );
    final feature = tester.getRect(
      find.byKey(const Key('story-card-stack-feature')),
    );
    expect(card.top, greaterThanOrEqualTo(close.bottom + 8));
    expect(card.bottom, lessThanOrEqualTo(feature.top - 8));
  });

  testWidgets('상세 카드 확대 후에는 한 손가락으로 이동하고 화면 넘김과 닫기를 막는다', (tester) async {
    final items = [
      _item(id: 'card-1', minute: 1),
      _item(id: 'card-2', minute: 2),
    ];
    await _pumpOverlay(tester, items: items, initialCardId: 'card-1');
    await _open(tester);

    final card = find.byKey(const Key('story-card-stack-card-1'));
    final center = tester.getCenter(card);
    final first = await tester.startGesture(center - const Offset(30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));
    await first.moveTo(center - const Offset(70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final viewport = tester.widget<StoryCardInteractiveViewport>(
      find.byType(StoryCardInteractiveViewport),
    );
    expect(viewport.controller.scale, greaterThan(1.5));

    final beforePan = viewport.controller.translation;
    await tester.drag(card, const Offset(0, 70));
    await tester.pumpAndSettle();

    expect(viewport.controller.translation.dy, greaterThan(beforePan.dy));
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byKey(const Key('story-card-stack-overlay')), findsOneWidget);
  });
}

Future<void> _pumpOverlay(
  WidgetTester tester, {
  required List<StoryCardStackItem> items,
  String? initialCardId,
  bool isMine = true,
  StoryCardDownloader? downloader,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyCardStackProvider.overrideWith(
          (ref, request) => Future.value(items),
        ),
        if (downloader != null)
          storyCardDownloaderProvider.overrideWithValue(downloader),
      ],
      child: MaterialApp(
        home: _OverlayLauncher(
          items: items,
          initialCardId: initialCardId,
          isMine: isMine,
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

class _OverlayLauncher extends StatelessWidget {
  const _OverlayLauncher({
    required this.items,
    required this.initialCardId,
    required this.isMine,
  });

  final List<StoryCardStackItem> items;
  final String? initialCardId;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final latest = items.last.card;
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => showStoryCardStackOverlay(
            context: context,
            date: DateTime(2026, 9, 14),
            stack: StoryCardStackPreview(
              authorUserId: latest.authorUserId,
              latestCard: StoryLoopCardPreview(
                id: latest.id,
                authorUserId: latest.authorUserId,
                previewPath: latest.previewPath,
                submittedAt: latest.submittedAt,
                cardType: latest.cardType,
                previewUrl: latest.previewUrl,
              ),
              latestCardIsFeatured: false,
              cardCount: items.length,
              isMine: isMine,
            ),
            initialCardId: initialCardId,
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

StoryCardStackItem _item({
  required String id,
  required int minute,
  StoryCardType cardType = StoryCardType.polaroid,
}) {
  return StoryCardStackItem(
    position: minute,
    card: StoryLoopCardDetail(
      id: id,
      authorUserId: 'author-id',
      previewPath: 'previews/$id.png',
      sceneDataPath: 'scenes/$id.json',
      hasPhoto: true,
      hasDrawing: false,
      hasText: false,
      submittedAt: DateTime(2026, 9, 14, 10, minute),
      revision: 1,
      cardType: cardType,
    ),
    isFeatured: false,
    canDelete: true,
    canFeature: true,
    isRead: true,
  );
}

class _FakeStoryCardDownloader implements StoryCardDownloader {
  final cardIds = <String>[];

  @override
  Future<void> download(String cardId) async {
    cardIds.add(cardId);
  }
}
