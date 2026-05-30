import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('shows active couple day count and home placeholders', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      couple: _activeCouple,
      today: DateTime(2026, 5, 31),
    );

    expect(find.text('우리 둘'), findsOneWidget);
    expect(find.text('D+2일', findRichText: true), findsOneWidget);
    expect(find.text('오늘의 질문'), findsOneWidget);
    expect(find.text('준비 중'), findsOneWidget);
    expect(find.text('캐릭터 준비 중'), findsOneWidget);
    expect(find.text('표현'), findsNWidgets(4));
  });

  testWidgets('shows missing couple message', (tester) async {
    await _pumpHome(tester, couple: null);

    expect(find.text('커플 정보를 찾을 수 없어요.'), findsOneWidget);
  });

  testWidgets('shows pending couple message', (tester) async {
    await _pumpHome(tester, couple: _pendingCouple);

    expect(find.text('커플 연결을 완료해주세요.'), findsOneWidget);
  });

  testWidgets('shows missing relationship start date message', (tester) async {
    await _pumpHome(tester, couple: _activeCoupleWithoutDate);

    expect(find.text('첫 만남일을 먼저 입력해주세요.'), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required Couple? couple,
  DateTime? today,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => couple,
        ),
        todayControllerProvider.overrideWithBuild(
          (ref, notifier) => today ?? DateTime(2026, 5, 31),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );

  await tester.pumpAndSettle();
}

final _pendingCouple = Couple(
  id: 'couple-id',
  inviteCode: 'ABC234',
  userAId: 'user-id',
  timezone: 'Asia/Seoul',
  status: CoupleStatus.pending,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _activeCoupleWithoutDate = Couple(
  id: 'couple-id',
  inviteCode: 'ABC234',
  userAId: 'user-id',
  userBId: 'partner-id',
  timezone: 'Asia/Seoul',
  status: CoupleStatus.active,
  connectedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _activeCouple = Couple(
  id: 'couple-id',
  inviteCode: 'ABC234',
  userAId: 'user-id',
  userBId: 'partner-id',
  relationshipStartDate: DateTime(2026, 5, 30),
  timezone: 'Asia/Seoul',
  status: CoupleStatus.active,
  connectedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
