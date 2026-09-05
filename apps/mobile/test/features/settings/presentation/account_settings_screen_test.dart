import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/account/application/account_deletion_providers.dart';
import 'package:vinscent/features/account/application/account_deletion_service.dart';
import 'package:vinscent/features/account/application/account_local_data_cleanup.dart';
import 'package:vinscent/features/account/data/account_deletion_repository.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/settings/presentation/account_settings_screen.dart';

void main() {
  testWidgets('로그아웃과 계정 삭제를 별도 작업으로 보여준다', (tester) async {
    await _pumpAccountSettings(tester);

    expect(find.text('로그아웃'), findsOneWidget);
    expect(find.text('계정 삭제'), findsOneWidget);
    expect(
      find.byKey(const Key('account-settings-display-name-action')),
      findsOneWidget,
    );
    expect(find.text('또치'), findsOneWidget);
  });

  testWidgets('계정 삭제 전에 공유 데이터 범위와 복구 불가를 알린다', (tester) async {
    await _pumpAccountSettings(tester);

    await tester.tap(find.byKey(const Key('account-settings-delete-action')));
    await tester.pumpAndSettle();

    expect(find.text('계정을 삭제할까요?'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '계정과 두 사람이 함께 만든 카드, 녹음, 답변, 캐릭터, 일정, AI 데이터가 '
        '모두 영구 삭제돼요. 상대방 계정은 유지되지만 커플 연결은 해제되며, '
        '삭제한 데이터는 복구할 수 없어요',
      ),
      findsOneWidget,
    );
  });

  testWidgets('삭제 확인 시 현재 사용자 계정을 한 번만 삭제한다', (tester) async {
    final executor = _FakeAccountDeletionExecutor();
    await _pumpAccountSettings(tester, executor: executor);

    await tester.tap(find.byKey(const Key('account-settings-delete-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
    await tester.pumpAndSettle();

    expect(executor.userIds, ['user-a']);
  });

  testWidgets('삭제 취소 시 계정 삭제를 요청하지 않는다', (tester) async {
    final executor = _FakeAccountDeletionExecutor();
    await _pumpAccountSettings(tester, executor: executor);

    await tester.tap(find.byKey(const Key('account-settings-delete-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-confirmation-cancel')));
    await tester.pumpAndSettle();

    expect(executor.userIds, isEmpty);
  });
}

Future<void> _pumpAccountSettings(
  WidgetTester tester, {
  AccountDeletionExecutor? executor,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        accountCurrentUserIdProvider.overrideWithValue('user-a'),
        accountDeletionExecutorProvider.overrideWithValue(
          executor ?? _FakeAccountDeletionExecutor(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: AccountSettingsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

final _profile = UserProfile(
  id: 'user-a',
  displayName: '또치',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _FakeAccountDeletionExecutor implements AccountDeletionExecutor {
  final userIds = <String>[];

  @override
  Future<AccountDeletionOutcome> execute({
    required String userId,
    String? appleAuthorizationCode,
  }) async {
    userIds.add(userId);
    return AccountDeletionOutcome(
      receipt: const AccountDeletionReceipt(deletedCoupleCount: 1),
      localCleanup: AccountLocalDataCleanupResult(failures: const []),
    );
  }
}
