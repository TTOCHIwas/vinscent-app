import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';
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

  testWidgets('연결 해제 확인 버튼은 위험 동작 색상으로 표시한다', (tester) async {
    await _pumpCoupleSettings(tester, couple: activeCouple());

    await tester.tap(
      find.byKey(const Key('couple-settings-disconnect-action')),
    );
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '연결 해제'),
    );
    final foregroundColor = confirmButton.style?.foregroundColor?.resolve({});

    expect(
      foregroundColor,
      Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.error,
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

  testWidgets('연결 해제를 처리하는 동안 작업 행에 진행 상태를 표시한다', (
    tester,
  ) async {
    final repository = _PendingCoupleRepository();
    await _pumpCoupleSettings(
      tester,
      couple: activeCouple(),
      repository: repository,
    );

    final action = find.byKey(
      const Key('couple-settings-disconnect-action'),
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '연결 해제'));
    await tester.pump();

    expect(
      find.descendant(
        of: action,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpCoupleSettings(
  WidgetTester tester, {
  required Couple? couple,
  Object? buildError,
  CoupleRepository? repository,
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
