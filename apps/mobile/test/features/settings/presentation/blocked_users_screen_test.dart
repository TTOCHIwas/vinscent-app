import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/presentation/widgets/app_confirmation_sheet.dart';
import 'package:vinscent/features/safety/application/user_block_providers.dart';
import 'package:vinscent/features/safety/application/user_block_service.dart';
import 'package:vinscent/features/safety/data/user_block.dart';
import 'package:vinscent/features/settings/presentation/blocked_users_screen.dart';

void main() {
  testWidgets('explains that unblocking does not restore the couple', (
    tester,
  ) async {
    final service = _FakeUserBlockService();
    await _pump(
      tester,
      service: service,
      blockedUsers: [
        BlockedUser(
          userId: 'blocked-user-id',
          displayName: '또치',
          blockedAt: _blockedAt,
        ),
      ],
    );

    expect(find.text('또치'), findsOneWidget);
    expect(find.text('2026.07.28 차단'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('blocked-user-unblock-blocked-user-id')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmationSheet), findsOneWidget);
    expect(find.text('차단을 해제해도 커플 연결과 기록은 자동으로 복구되지 않아요'), findsOneWidget);

    await tester.tap(find.text('차단 해제'));
    await tester.pumpAndSettle();

    expect(service.unblockedUserId, 'blocked-user-id');
  });

  testWidgets('shows a calm empty state when no user is blocked', (
    tester,
  ) async {
    await _pump(
      tester,
      service: _FakeUserBlockService(),
      blockedUsers: const [],
    );

    expect(find.text('차단한 사용자가 없어요'), findsOneWidget);
    expect(find.text('차단한 사용자는 여기에서 관리할 수 있어요'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeUserBlockService service,
  required List<BlockedUser> blockedUsers,
}) async {
  final router = GoRouter(
    initialLocation: '/settings/blocked-users',
    routes: [
      GoRoute(
        path: '/settings/blocked-users',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/couple',
        builder: (context, state) => const Text('couple entry'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        blockedUsersProvider.overrideWith((ref) async => blockedUsers),
        userBlockServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeUserBlockService implements UserBlockService {
  String? unblockedUserId;

  @override
  Future<void> blockCurrentPartner() => throw UnimplementedError();

  @override
  Future<void> createReconnectInvite(String coupleId) =>
      throw UnimplementedError();

  @override
  Future<bool> unblockUser(String userId) async {
    unblockedUserId = userId;
    return true;
  }
}

final _blockedAt = DateTime.utc(2026, 7, 28);
