import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/data/safety_report_failure.dart';
import 'package:vinscent/features/safety/data/safety_report_repository.dart';
import 'package:vinscent/features/safety/presentation/safety_report_sheet.dart';

void main() {
  testWidgets('submits an AI report and closes the root sheet', (tester) async {
    final repository = _FakeSafetyReportRepository();
    final rootObserver = _RouteObserver();
    final branchObserver = _RouteObserver();
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          safetyReportRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          navigatorObservers: [rootObserver],
          home: Navigator(
            observers: [branchObserver],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showSafetyReportSheet(
                      context: context,
                      target: const SafetyReportTarget(
                        type: SafetyReportTargetType.aiDirectAnswer,
                        id: 'direct-answer-id',
                        contentSnapshot: '생성된 답변',
                      ),
                    );
                  },
                  child: const Text('신고 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    rootObserver.pushedRoutes.clear();
    branchObserver.pushedRoutes.clear();

    await tester.tap(find.text('신고 열기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-report-sheet')), findsOneWidget);
    expect(
      find.byKey(const Key('safety-report-reason-unsafeAi')),
      findsOneWidget,
    );
    expect(
      rootObserver.pushedRoutes.last,
      isA<ModalBottomSheetRoute<dynamic>>(),
    );
    expect(
      branchObserver.pushedRoutes.whereType<ModalBottomSheetRoute<dynamic>>(),
      isEmpty,
    );

    await tester.tap(find.byKey(const Key('safety-report-reason-unsafeAi')));
    await tester.enterText(
      find.byKey(const Key('safety-report-details')),
      '이 답변은 위험할 수 있어요',
    );
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pumpAndSettle();

    expect(repository.requests, [
      const SafetyReportRequest(
        target: SafetyReportTarget(
          type: SafetyReportTargetType.aiDirectAnswer,
          id: 'direct-answer-id',
          contentSnapshot: '생성된 답변',
        ),
        reason: SafetyReportReason.unsafeAi,
        details: '이 답변은 위험할 수 있어요',
      ),
    ]);
    expect(result, isTrue);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('keeps the sheet open when submission fails', (tester) async {
    final repository = _FakeSafetyReportRepository(
      error: const SafetyReportException(
        SafetyReportFailureReason.authRequired,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          safetyReportRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSafetyReportSheet(
                  context: context,
                  target: const SafetyReportTarget(
                    type: SafetyReportTargetType.partner,
                    id: 'partner-id',
                  ),
                ),
                child: const Text('신고 열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('신고 열기'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('safety-report-reason-harassment')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('safety-report-reason-unsafeAi')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('safety-report-reason-harassment')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pump();

    expect(find.byKey(const Key('safety-report-sheet')), findsOneWidget);
    expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요'), findsOneWidget);
  });

  testWidgets('prevents duplicate submissions while a report is pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repository = _FakeSafetyReportRepository(pending: pending);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          safetyReportRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSafetyReportSheet(
                  context: context,
                  target: const SafetyReportTarget(
                    type: SafetyReportTargetType.aiFeedback,
                    id: 'feedback-id',
                  ),
                ),
                child: const Text('신고 열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('신고 열기'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('safety-report-reason-inappropriate')),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pump();

    expect(repository.requests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete();
    await tester.pumpAndSettle();
  });
}

class _FakeSafetyReportRepository implements SafetyReportRepository {
  _FakeSafetyReportRepository({this.error, this.pending});

  final Object? error;
  final Completer<void>? pending;
  final List<SafetyReportRequest> requests = [];

  @override
  Future<void> submit(SafetyReportRequest request) async {
    requests.add(request);
    if (error case final Object error) {
      throw error;
    }
    await pending?.future;
  }
}

class _RouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
