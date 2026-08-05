import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/core/presentation/widgets/app_action_button.dart';
import 'package:vinscent/core/presentation/widgets/app_confirmation_sheet.dart';
import 'package:vinscent/core/presentation/widgets/character_placeholder.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/presentation/couple_entry_screen.dart';
import 'package:vinscent/features/couple/presentation/couple_setup_waiting_screen.dart';
import 'package:vinscent/features/couple/presentation/couple_waiting_screen.dart';
import 'package:vinscent/features/couple/presentation/relationship_start_date_screen.dart';
import 'package:vinscent/features/safety/application/user_block_providers.dart';
import 'package:vinscent/features/safety/application/user_block_service.dart';
import 'package:vinscent/features/safety/data/user_block.dart';

void main() {
  testWidgets('separates invite creation from code entry', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CoupleEntryScreen())),
    );

    expect(find.byKey(const Key('couple-connection-mode-selector')), findsOne);
    expect(find.text('초대 코드 만들기'), findsOne);
    expect(find.byType(TextField), findsNothing);
    expect(_primaryActionColor(tester), AppColors.brandAction);
    final selectedMode = find.ancestor(
      of: find.text('초대하기'),
      matching: find.byType(Material),
    );
    expect(
      tester.widget<Material>(selectedMode.first).color,
      AppColors.brandSurface,
    );
    final selectorRect = tester.getRect(
      find.byKey(const Key('couple-connection-mode-selector')),
    );
    final selectedModeRect = tester.getRect(selectedMode.first);
    expect(selectedModeRect.height, selectorRect.height - 8);
    expect(selectedModeRect.top, selectorRect.top + 4);

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

  testWidgets('offers an explicit reconnect invite for an available archive', (
    tester,
  ) async {
    final service = _FakeUserBlockService();
    await _pumpCoupleEntry(
      tester,
      service: service,
      reconnectableArchives: [
        ReconnectableCoupleArchive(
          coupleId: 'archived-couple-id',
          partnerUserId: 'partner-id',
          partnerDisplayName: '또치',
          archiveExpiresAt: DateTime(2026, 8, 27),
        ),
      ],
    );

    expect(find.text('또치님과 다시 연결'), findsOneWidget);
    expect(find.text('2026.08.27까지 기존 기록을 이어갈 수 있어'), findsOneWidget);
    expect(find.text('초대 코드 만들기'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('couple-reconnect-archive-archived-couple-id')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmationSheet), findsOneWidget);
    expect(find.textContaining('차단 해제만으로는 다시 연결되지 않아'), findsOneWidget);

    await tester.tap(find.text('재연결 초대 만들기'));
    await tester.pumpAndSettle();

    expect(service.reconnectedCoupleId, 'archived-couple-id');
  });

  testWidgets('keeps blocked user management available from couple entry', (
    tester,
  ) async {
    await _pumpCoupleEntry(tester, service: _FakeUserBlockService());

    await tester.tap(
      find.byKey(const Key('couple-entry-blocked-users-action')),
    );
    await tester.pumpAndSettle();

    expect(find.text('blocked users'), findsOneWidget);
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

  testWidgets('confirms before leaving incomplete relationship setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RelationshipStartDateScreen()),
      ),
    );

    await tester.tap(find.byTooltip('이전'));
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmationSheet), findsOneWidget);
    expect(find.text('커플 연결 설정을 그만둘까?'), findsOneWidget);
    expect(find.text('연결 취소'), findsOneWidget);
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

Color? _primaryActionColor(WidgetTester tester) {
  final action = find.byType(AppActionButton);
  return tester
      .widget<Material>(
        find.descendant(of: action, matching: find.byType(Material)),
      )
      .color;
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

Future<void> _pumpCoupleEntry(
  WidgetTester tester, {
  required _FakeUserBlockService service,
  List<ReconnectableCoupleArchive> reconnectableArchives = const [],
}) async {
  final router = GoRouter(
    initialLocation: '/couple',
    routes: [
      GoRoute(
        path: '/couple',
        builder: (context, state) => const CoupleEntryScreen(),
      ),
      GoRoute(
        path: '/settings/blocked-users',
        builder: (context, state) => const Text('blocked users'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reconnectableCoupleArchivesProvider.overrideWith(
          (ref) async => reconnectableArchives,
        ),
        userBlockServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeUserBlockService implements UserBlockService {
  String? reconnectedCoupleId;

  @override
  Future<void> blockCurrentPartner() => throw UnimplementedError();

  @override
  Future<void> createReconnectInvite(String coupleId) async {
    reconnectedCoupleId = coupleId;
  }

  @override
  Future<bool> unblockUser(String userId) => throw UnimplementedError();
}
