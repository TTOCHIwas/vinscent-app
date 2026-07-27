import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/core/presentation/widgets/character_placeholder.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/presentation/couple_entry_screen.dart';
import 'package:vinscent/features/couple/presentation/couple_setup_waiting_screen.dart';
import 'package:vinscent/features/couple/presentation/couple_waiting_screen.dart';
import 'package:vinscent/features/couple/presentation/relationship_start_date_screen.dart';

void main() {
  testWidgets('separates invite creation from code entry', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CoupleEntryScreen())),
    );

    expect(find.byKey(const Key('couple-connection-mode-selector')), findsOne);
    expect(find.text('초대 코드 만들기'), findsOne);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('코드 입력'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOne);
    expect(find.text('연결하기'), findsOne);
    expect(find.text('초대 코드 만들기'), findsNothing);

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.filled, isTrue);
  });

  testWidgets('keeps waiting actions subordinate to the invite code', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleControllerProvider.overrideWithBuild(
            (ref, notifier) async => _pendingCouple,
          ),
        ],
        child: const MaterialApp(home: CoupleWaitingScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC234'), findsOneWidget);
    expect(find.byTooltip('초대 코드 복사'), findsOneWidget);
    expect(find.byTooltip('연결 상태 새로고침'), findsOneWidget);
    expect(find.text('초대 취소'), findsOneWidget);
    expect(find.text('초대 코드 복사'), findsNothing);
  });

  testWidgets('does not overflow the connection screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.6),
            ),
            child: const CoupleEntryScreen(),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the shared date field before character setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayControllerProvider.overrideWithBuild(
            (ref, notifier) => DateTime(2026, 7, 28),
          ),
        ],
        child: const MaterialApp(home: RelationshipStartDateScreen()),
      ),
    );

    expect(find.text('우리가 처음 만난 날은?'), findsOneWidget);
    expect(
      find.byKey(const Key('relationship-start-date-field')),
      findsOneWidget,
    );
    expect(find.text('다음'), findsOneWidget);

    await tester.tap(find.byKey(const Key('relationship-start-date-field')));
    await tester.pumpAndSettle();

    expect(find.text('만난 날 선택'), findsOneWidget);
    expect(find.byKey(const Key('app-date-picker-year')), findsOneWidget);
  });

  testWidgets('centers the waiting character on a tablet', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: CoupleSetupWaitingScreen()),
    );

    final characterCenter = tester.getCenter(find.byType(CharacterPlaceholder));
    expect(characterCenter.dx, moreOrLessEquals(512, epsilon: 1));
    expect(find.text('설정 중입니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _pendingCouple = Couple(
  id: 'couple-id',
  inviteCode: 'ABC234',
  userAId: 'user-a',
  timezone: 'Asia/Seoul',
  status: CoupleStatus.pending,
  accessMode: CoupleAccessMode.pending,
  createdAt: DateTime(2026, 7, 28),
  updatedAt: DateTime(2026, 7, 28),
);
