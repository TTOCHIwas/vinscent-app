import 'dart:ui' show SemanticsAction;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/widgets/monthly_retrospective_pager.dart';

void main() {
  testWidgets(
    'screen reader adjusts the compact page control in both directions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthlyRetrospectivePager(
              month: DateTime(2026, 9),
              pages: const ['overview', 'moments', 'reflection'],
              pageBuilder: (page) => Center(child: Text(page)),
            ),
          ),
        ),
      );
      var node = tester.getSemantics(find.bySemanticsLabel('월간 회고 페이지'));
      expect(node.getSemanticsData().value, 'overview, 1/3페이지');
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pumpAndSettle();
      expect(find.text('moments').hitTestable(), findsOneWidget);
      node = tester.getSemantics(find.bySemanticsLabel('월간 회고 페이지'));
      expect(node.getSemanticsData().value, 'moments, 2/3페이지');
      node.owner!.performAction(node.id, SemanticsAction.decrease);
      await tester.pumpAndSettle();
      expect(find.text('overview').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'swipes between pages and retains the logical page when a shared answer arrives',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final shared = ValueNotifier(false);
      addTearDown(shared.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: shared,
              builder: (context, hasSharedAnswer, child) =>
                  MonthlyRetrospectivePager(
                    month: DateTime(2026, 9),
                    pages: [
                      'overview',
                      'moments',
                      if (hasSharedAnswer) 'conversation',
                      'reflection',
                    ],
                    pageBuilder: (page) => Center(child: Text(page)),
                  ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('monthly-page-indicator-3')), findsNothing);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('moments').hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('monthly-page-indicator-2')));
      await tester.pumpAndSettle();
      expect(find.text('reflection').hitTestable(), findsOneWidget);
      shared.value = true;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('monthly-page-indicator-3')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('monthly-page-control'))),
        const Size(72, 44),
      );
      expect(find.text('reflection').hitTestable(), findsOneWidget);
      shared.value = false;
      await tester.pumpAndSettle();
      expect(find.text('reflection').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'starts a new month on the overview and hides indicators for an empty month',
    (tester) async {
      final month = ValueNotifier(DateTime(2026, 9));
      addTearDown(month.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: month,
              builder: (context, value, child) => MonthlyRetrospectivePager(
                month: value,
                pages: value.month == 9
                    ? ['overview', 'moments', 'reflection']
                    : ['overview'],
                pageBuilder: (page) => Center(child: Text(page)),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('monthly-page-indicator-2')));
      await tester.pumpAndSettle();
      month.value = DateTime(2026, 10);
      await tester.pumpAndSettle();
      expect(find.text('overview').hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('monthly-page-control')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
