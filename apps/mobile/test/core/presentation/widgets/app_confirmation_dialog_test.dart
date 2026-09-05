import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_confirmation_sheet.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/core/theme/app_theme.dart';

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

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('항목을 삭제할까요?'), findsOneWidget);
      expect(find.text('삭제하면 복구할 수 없어요.'), findsOneWidget);
      expect(
        rootObserver.pushedRoutes.last,
        isA<DialogRoute<dynamic>>(),
      );
      expect(
        branchObserver.pushedRoutes.whereType<DialogRoute<dynamic>>(),
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

  testWidgets('outside taps do not discard and system back cancels', (
    tester,
  ) async {
    bool? result;
    await _openConfirmation(tester, onResult: (value) => result = value);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(result, isNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final destructive in [true, false]) {
    testWidgets('text actions distinguish destructive=$destructive', (
      tester,
    ) async {
      await _openConfirmation(tester, isDestructive: destructive);
      final confirm = tester.widget<TextButton>(
        find.byKey(const Key('app-confirmation-confirm')),
      );
      final cancel = tester.widget<TextButton>(
        find.byKey(const Key('app-confirmation-cancel')),
      );
      expect(
        confirm.style?.foregroundColor?.resolve({}),
        destructive ? AppColors.recordingActive : AppColors.textPrimary,
      );
      for (final button in [confirm, cancel]) {
        expect(
          button.style?.backgroundColor?.resolve({}),
          anyOf(isNull, Colors.transparent),
        );
      }
    });
  }

  for (final layout in [
    (size: const Size(360, 800), scale: 1.0, stacked: false),
    (size: const Size(320, 568), scale: 2.0, stacked: true),
    (size: const Size(320, 568), scale: 3.0, stacked: true),
    (size: const Size(640, 360), scale: 2.0, stacked: true),
    (size: const Size(900, 1200), scale: 1.0, stacked: false),
  ]) {
    testWidgets('keeps actions readable at $layout', (tester) async {
      await tester.binding.setSurfaceSize(layout.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openConfirmation(tester, textScale: layout.scale);

      expect(find.byType(AlertDialog), findsOneWidget);
      final surface = tester.getRect(
        find.descendant(of: find.byType(Dialog), matching: find.byType(Material)),
      );
      final cancel = tester.getRect(
        find.byKey(const Key('app-confirmation-cancel')),
      );
      final confirm = tester.getRect(
        find.byKey(const Key('app-confirmation-confirm')),
      );
      expect(surface.width, lessThanOrEqualTo(400));
      expect(surface.center.dx, closeTo(layout.size.width / 2, 0.01));
      expect(surface.center.dy, closeTo(layout.size.height / 2, 0.01));
      expect(surface.top, greaterThanOrEqualTo(24));
      expect(surface.bottom, lessThanOrEqualTo(layout.size.height - 24));
      for (final button in [confirm, cancel]) {
        expect(button.height, greaterThanOrEqualTo(48));
        expect(surface.contains(button.topLeft), isTrue);
        expect(surface.contains(button.bottomRight), isTrue);
      }
      if (layout.stacked) {
        expect(cancel.bottom, lessThanOrEqualTo(confirm.top));
      } else {
        expect(cancel.center.dy, closeTo(confirm.center.dy, 0.01));
        expect(cancel.right, lessThanOrEqualTo(confirm.left));
      }
      final label = tester.element(find.text('수정 버리기'));
      expect(MediaQuery.textScalerOf(label).scale(16), 16 * layout.scale);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('app-confirmation-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('long account warning scrolls without hiding actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    bool? result;
    await _openConfirmation(
      tester,
      textScale: 2,
      message: List.filled(12, '삭제한 데이터는 복구할 수 없어요.').join('\n'),
      onResult: (value) => result = value,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}

Future<void> _openConfirmation(
  WidgetTester tester, {
  double textScale = 1,
  bool isDestructive = true,
  String message = '저장하지 않은 변경 내용이 사라져요.',
  ValueChanged<bool>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showAppConfirmationSheet(
                context: context,
                title: '수정 내용을 버릴까요?',
                message: message,
                confirmLabel: '수정 버리기',
                cancelLabel: '계속 수정',
                isDestructive: isDestructive,
              );
              onResult?.call(result);
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

class _RouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
