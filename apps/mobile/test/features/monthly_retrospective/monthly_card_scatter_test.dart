import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective_repository.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/widgets/monthly_card_scatter.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';

void main() {
  testWidgets('keeps old cards ready while a newly added card awaits signing', (
    tester,
  ) async {
    final repository = _Repository()..urls = {'preview-0': 'unavailable'};
    final count = ValueNotifier(1);
    addTearDown(count.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyRetrospectiveRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: count,
              builder: (context, value, _) => MonthlyCardScatter(
                cards: [
                  for (var i = 0; i < value; i++)
                    (date: _card(i).date, card: _card(i)),
                ],
                onOpenCard: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.pending = Completer<Map<String, String>>();
    count.value = 2;
    await tester.pump();
    await tester.pump();
    final surfaces = tester
        .widgetList<StoryCardPreviewSurface>(
          find.byType(StoryCardPreviewSurface),
        )
        .toList();
    expect(surfaces[0].isLoading, false);
    expect(surfaces[1].isLoading, true);
    repository.pending!.complete({
      'preview-0': 'unavailable',
      'preview-1': 'unavailable',
    });
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<StoryCardPreviewSurface>(
            find.byType(StoryCardPreviewSurface),
          )
          .every((card) => !card.isLoading),
      true,
    );
  });

  test(
    'selects at most eight stable cards across both authors and the month',
    () {
      final gallery = [for (var i = 0; i < 30; i++) _card(i)];
      final selected = selectMonthlyScatterCards(gallery);
      expect(selected, hasLength(8));
      expect(selected.map((e) => e.card.authorUserId).toSet(), {'a', 'b'});
      expect(selected.first.date.day, 1);
      expect(selected.last.date.day, 30);
      expect(
        selectMonthlyScatterCards(
          gallery.reversed.toList(),
        ).map((e) => e.card.id),
        selected.map((e) => e.card.id),
      );
      expect(selectMonthlyScatterCards(gallery.take(2).toList()), hasLength(2));
      expect(selectMonthlyScatterCards([]), isEmpty);
      for (final entry in [(3, 3), (4, 4), (9, 4), (10, 6), (19, 6), (20, 8)]) {
        final cards = gallery.take(entry.$1).toList();
        final selection = selectMonthlyScatterCards(cards);
        expect(selection, hasLength(entry.$2));
        expect(selection.map((e) => e.card.authorUserId).toSet(), {'a', 'b'});
        expect(
          selectMonthlyScatterCards(
            cards.reversed.toList(),
          ).map((e) => e.card.id),
          selection.map((e) => e.card.id),
        );
      }
    },
  );

  testWidgets('shows an overlapping pile and opens the actual tapped card', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final selected = selectMonthlyScatterCards([
      for (var i = 0; i < 30; i++) _card(i),
    ]);
    MonthlyScatterCard? opened;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlyRetrospectiveRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: MonthlyCardScatter(
                cards: selected,
                compact: true,
                onOpenCard: (entry) => opened = entry,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requestedPaths, hasLength(8));
    final first = tester.getRect(
      find.byKey(ValueKey('monthly-card-${selected[0].card.id}')),
    );
    final second = tester.getRect(
      find.byKey(ValueKey('monthly-card-${selected[1].card.id}')),
    );
    expect(first.overlaps(second), isTrue);
    await tester.tap(
      find.byKey(ValueKey('monthly-card-${selected.last.card.id}')),
    );
    expect(opened?.card.id, selected.last.card.id);
    expect(opened?.date, selected.last.date);
    opened = null;
    final lastCard = tester.renderObject<RenderBox>(
      find.byKey(ValueKey('monthly-card-${selected.last.card.id}')),
    );
    await tester.tapAt(
      lastCard.localToGlobal(
        Offset(lastCard.size.width - 4, lastCard.size.height - 4),
      ),
    );
    expect(opened?.card.id, selected.last.card.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps tall card proportions and revalidates URL leases on rebuild',
    (tester) async {
      final repository = _Repository();
      final version = ValueNotifier(0);
      addTearDown(version.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyRetrospectiveRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder(
                valueListenable: version,
                builder: (context, value, child) => MonthlyCardScatter(
                  cards: [
                    for (var i = 0; i < 2; i++)
                      (date: _card(i).date, card: _card(i)),
                  ],
                  onOpenCard: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final photo = tester.getSize(
        find.byKey(const ValueKey('monthly-card-c0')),
      );
      final strip = tester.getSize(
        find.byKey(const ValueKey('monthly-card-c1')),
      );
      expect(strip.height, closeTo(photo.height, 0.01));
      expect(strip.width / strip.height, closeTo(8 / 21, 0.001));
      expect(
        tester
            .getRect(find.byKey(const ValueKey('monthly-card-c0')))
            .overlaps(
              tester.getRect(find.byKey(const ValueKey('monthly-card-c1'))),
            ),
        isTrue,
      );
      version.value++;
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

RetrospectiveGalleryCard _card(int index) => RetrospectiveGalleryCard.fromJson({
  'id': 'c$index',
  'date': '2026-09-${(index + 1).toString().padLeft(2, '0')}',
  'preview_path': 'preview-$index',
  'author_user_id': index.isEven ? 'a' : 'b',
  'aspect_ratio': index == 1 ? 8 / 21 : 0.8,
  'card_type': index == 1 ? 'four_cut_strip' : 'polaroid',
  'layout_version': 2,
});

class _Repository implements MonthlyRetrospectiveRepository {
  int calls = 0;
  Map<String, String> urls = {};
  Completer<Map<String, String>>? pending;
  List<String> requestedPaths = [];
  @override
  Future<Map<String, String>> previewUrls(
    Iterable<RetrospectiveCard> cards,
  ) async {
    calls++;
    requestedPaths = cards.map((card) => card.previewPath).toList();
    return pending?.future ?? urls;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
