import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/presentation/widgets/app_confirmation_sheet.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/data/safety_report_repository.dart';
import 'package:vinscent/features/safety/application/user_block_service.dart';
import 'package:vinscent/features/settings/presentation/couple_settings_screen.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  testWidgets('활성 커플의 상태와 위험 작업을 설정 목록으로 구분한다', (tester) async {
    await _pumpCoupleSettings(tester, couple: activeCouple());

    expect(find.text('연결 상태'), findsOneWidget);
    expect(find.text('연결 관리'), findsOneWidget);
    expect(
      find.byKey(const Key('couple-settings-disconnect-action')),
      findsOneWidget,
    );
  });

  testWidgets('커플 정보를 불러오지 못하면 다시 시도할 수 있다', (tester) async {
    await _pumpCoupleSettings(
      tester,
      couple: null,
      buildError: StateError('load failed'),
    );

    expect(find.text('커플 정보를 불러오지 못했어요.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '다시 시도'), findsOneWidget);
  });

  testWidgets('연결 해제는 공통 위험 동작 하단 시트로 확인한다', (tester) async {
    await _pumpCoupleSettings(tester, couple: activeCouple());

    await tester.tap(
      find.byKey(const Key('couple-settings-disconnect-action')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppConfirmationSheet), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '연결을 해제해도 답변과 캐릭터 기록은 30일 동안 보관돼요. '
        '보관 기간 안에는 기존 초대 코드 흐름으로 다시 연결할 수 있어요.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('보관 중인 커플은 만료일과 복구·삭제 작업을 구분한다', (tester) async {
    await _pumpCoupleSettings(
      tester,
      couple: archivedReadOnlyCouple(archiveExpiresAt: DateTime(2026, 7, 31)),
    );

    expect(find.text('보관 상태'), findsOneWidget);
    expect(find.textContaining('2026.07.31'), findsOneWidget);
    expect(
      find.byKey(const Key('couple-settings-reconnect-action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('couple-settings-delete-action')),
      findsOneWidget,
    );
  });

  testWidgets('연결 해제를 처리하는 동안 작업 행에 진행 상태를 표시한다', (tester) async {
    final repository = _PendingCoupleRepository();
    await _pumpCoupleSettings(
      tester,
      couple: activeCouple(),
      repository: repository,
    );

    final action = find.byKey(const Key('couple-settings-disconnect-action'));
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
    await tester.pump();

    expect(
      find.descendant(
        of: action,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reports the current partner from couple settings', (
    tester,
  ) async {
    final safetyRepository = _FakeSafetyReportRepository();
    await _pumpCoupleSettings(
      tester,
      couple: activeCouple(),
      safetyReportRepository: safetyRepository,
    );

    final reportAction = find.byKey(
      const Key('couple-settings-report-partner-action'),
    );
    expect(reportAction, findsOneWidget);

    await tester.tap(reportAction);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('safety-report-reason-harassment')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pumpAndSettle();

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.partner,
        id: 'partner-id',
      ),
    );
  });

  testWidgets(
    'blocks the current partner after explaining the safety boundary',
    (tester) async {
      final userBlockService = _FakeUserBlockService();
      await _pumpCoupleSettings(
        tester,
        couple: activeCouple(),
        userBlockService: userBlockService,
      );

      await tester.tap(
        find.byKey(const Key('couple-settings-block-partner-action')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppConfirmationSheet), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          '차단하면 커플 연결이 즉시 해제되고 두 사람의 공유 기록은 30일 동안 '
          '서로에게 보이지 않아요. 차단을 해제해도 자동으로 다시 연결되지 않아요.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
      await tester.pumpAndSettle();

      expect(userBlockService.blockCallCount, 1);
      expect(find.text('couple'), findsOneWidget);
    },
  );

  testWidgets('does not report a partner from archived settings', (
    tester,
  ) async {
    await _pumpCoupleSettings(tester, couple: archivedReadOnlyCouple());

    expect(
      find.byKey(const Key('couple-settings-report-partner-action')),
      findsNothing,
    );
  });
}

Future<void> _pumpCoupleSettings(
  WidgetTester tester, {
  required Couple? couple,
  Object? buildError,
  CoupleRepository? repository,
  SafetyReportRepository? safetyReportRepository,
  UserBlockService? userBlockService,
}) async {
  final router = GoRouter(
    initialLocation: '/settings/couple',
    routes: [
      GoRoute(
        path: '/settings/couple',
        builder: (context, state) => const CoupleSettingsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const Text('settings'),
      ),
      GoRoute(path: '/home', builder: (context, state) => const Text('home')),
      GoRoute(
        path: '/couple',
        builder: (context, state) => const Text('couple'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null)
          coupleRepositoryProvider.overrideWithValue(repository),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        if (safetyReportRepository != null)
          safetyReportRepositoryProvider.overrideWithValue(
            safetyReportRepository,
          ),
        if (userBlockService != null)
          userBlockServiceProvider.overrideWithValue(userBlockService),
        coupleControllerProvider.overrideWithBuild((ref, notifier) async {
          if (buildError case final error?) {
            throw error;
          }
          return couple;
        }),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSafetyReportRepository implements SafetyReportRepository {
  final requests = <SafetyReportRequest>[];

  @override
  Future<void> submit(SafetyReportRequest request) async {
    requests.add(request);
  }
}

class _FakeUserBlockService implements UserBlockService {
  int blockCallCount = 0;

  @override
  Future<void> blockCurrentPartner() async {
    blockCallCount += 1;
  }

  @override
  Future<void> createReconnectInvite(String coupleId) =>
      throw UnimplementedError();

  @override
  Future<bool> unblockUser(String userId) => throw UnimplementedError();
}

class _PendingCoupleRepository implements CoupleRepository {
  final disconnectCompleter = Completer<Couple>();

  @override
  Future<Couple> disconnectCouple() => disconnectCompleter.future;

  @override
  Future<Couple?> fetchCurrentCouple() async => activeCouple();

  @override
  Future<Couple?> cancelInvite() => throw UnimplementedError();

  @override
  Future<Couple> createInvite() => throw UnimplementedError();

  @override
  Future<void> deleteDisconnectedArchiveNow() => throw UnimplementedError();

  @override
  Future<Couple> joinByCode(String inviteCode) => throw UnimplementedError();

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) =>
      throw UnimplementedError();

  @override
  Future<Couple> useDefaultCharacter() => throw UnimplementedError();
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: 'User',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
