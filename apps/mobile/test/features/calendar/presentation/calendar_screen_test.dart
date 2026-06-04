import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';

void main() {
  testWidgets('shows current month and selection prompt', (tester) async {
    await _pumpCalendar(tester);

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsOneWidget);
  });

  testWidgets('does not move before relationship start month', (tester) async {
    await _pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 04월'), findsNothing);
  });

  testWidgets('moves to previous month after relationship start month', (
    tester,
  ) async {
    await _pumpCalendar(tester, today: DateTime(2026, 6, 2));

    expect(find.text('2026년 06월'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
  });

  testWidgets('does not move after today month', (tester) async {
    await _pumpCalendar(tester);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 06월'), findsNothing);
  });

  testWidgets('opens dated question route when past date is selected', (
    tester,
  ) async {
    await _pumpCalendar(tester);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('dated question route 2026-05-05'), findsOneWidget);
  });

  testWidgets('opens today question route when today is selected', (
    tester,
  ) async {
    await _pumpCalendar(tester);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    expect(find.text('today question route'), findsOneWidget);
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  DateTime? today,
  DateTime? relationshipStartDate,
}) async {
  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const Scaffold(body: CalendarScreen()),
      ),
      GoRoute(
        path: '/calendar/question',
        builder: (context, state) => Scaffold(
          body: Text(
            'dated question route ${state.uri.queryParameters['date']}',
          ),
        ),
      ),
      GoRoute(
        path: '/home/question',
        builder: (context, state) =>
            const Scaffold(body: Text('today question route')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayControllerProvider.overrideWithBuild(
          (ref, notifier) => today ?? DateTime(2026, 5, 10),
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async =>
              _activeCouple(relationshipStartDate: relationshipStartDate),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
}

Couple _activeCouple({DateTime? relationshipStartDate}) {
  return Couple(
    id: 'couple-id',
    inviteCode: 'ABC234',
    userAId: 'user-id',
    userBId: 'partner-id',
    relationshipStartDate: relationshipStartDate ?? DateTime(2026, 5, 1),
    timezone: 'Asia/Seoul',
    status: CoupleStatus.active,
    connectedAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}
