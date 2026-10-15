import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home/presentation/widgets/home_hanging_story_cards.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective_repository.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/widgets/monthly_card_clotheslines.dart';

void main() {
  testWidgets(
    'shows every card over multiple lines and opens the original date',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      DateTime? opened;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            monthlyRetrospectiveRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MonthlyCardClotheslines(
                  cards: _cards(9),
                  compact: true,
                  showDates: true,
                  onOpenRecord: (date) => opened = date,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeHangingStoryCards), findsNWidgets(3));
      expect(repository.calls, 1);
      expect(repository.requestedPaths, hasLength(9));
      final last = find.byKey(const ValueKey('monthly-card-c8'));
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      expect(opened, DateTime(2026, 9, 9));
      expect(tester.takeException(), isNull);
    },
  );

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
                builder: (context, value, child) => MonthlyCardClotheslines(
                  cards: _cards(2),
                  onOpenRecord: (_) {},
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
      version.value++;
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

List<MonthlyClotheslineCard> _cards(int count) => [
  for (var index = 0; index < count; index++)
    (
      date: DateTime(2026, 9, index + 1),
      card: RetrospectiveCard.fromJson({
        'id': 'c$index',
        'preview_path': 'preview-$index',
        'author_user_id': 'a',
        'aspect_ratio': index == 1 ? 8 / 21 : 0.8,
        'card_type': index == 1 ? 'four_cut_strip' : 'polaroid',
        'layout_version': 2,
      }),
    ),
];

class _Repository implements MonthlyRetrospectiveRepository {
  int calls = 0;
  List<String> requestedPaths = [];
  @override
  Future<Map<String, String>> previewUrls(
    Iterable<RetrospectiveCard> cards,
  ) async {
    calls++;
    requestedPaths = cards.map((card) => card.previewPath).toList();
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
