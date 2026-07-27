import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_confirmation_sheet.dart';

void main() {
  testWidgets(
    'opens above a nested navigator and returns the selected result',
    (tester) async {
      final rootObserver = _RouteObserver();
      final branchObserver = _RouteObserver();
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [rootObserver],
          home: Navigator(
            observers: [branchObserver],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAppConfirmationSheet(
                      context: context,
                      title: '항목을 삭제할까요?',
                      message: '삭제하면 복구할 수 없어요.',
                      confirmLabel: '삭제',
                    );
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      rootObserver.pushedRoutes.clear();
      branchObserver.pushedRoutes.clear();

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app-confirmation-sheet')), findsOneWidget);
      expect(find.text('항목을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제하면 복구할 수 없어요.'), findsOneWidget);
      expect(
        rootObserver.pushedRoutes.last,
        isA<ModalBottomSheetRoute<dynamic>>(),
      );
      expect(
        branchObserver.pushedRoutes.whereType<ModalBottomSheetRoute<dynamic>>(),
        isEmpty,
      );

      await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets('returns false from the separated cancel action', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showAppConfirmationSheet(
                  context: context,
                  title: '변경 내용을 버릴까요?',
                  confirmLabel: '나가기',
                  cancelLabel: '계속 수정',
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-confirmation-cancel')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });
}

class _RouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
