import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_confirmation_dialog.dart';
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
                    result = await showAppConfirmationDialog(
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
      expect(rootObserver.pushedRoutes.last, isA<DialogRoute<dynamic>>());
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
                result = await showAppConfirmationDialog(
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
    (size: const Size(360, 800), scale: 0.8),
    (size: const Size(360, 800), scale: 1.0),
    (size: const Size(320, 568), scale: 2.0),
    (size: const Size(320, 568), scale: 3.0),
    (size: const Size(640, 360), scale: 2.0),
    (size: const Size(900, 1200), scale: 1.0),
  ]) {
    testWidgets('keeps actions readable at $layout', (tester) async {
      await tester.binding.setSurfaceSize(layout.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _openConfirmation(tester, textScale: layout.scale);

      expect(find.byType(AlertDialog), findsOneWidget);
      final surface = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
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
      expect(cancel.bottom, lessThanOrEqualTo(confirm.top));
      expect(cancel.center.dx, closeTo(confirm.center.dx, 0.01));
      final label = tester.element(
        find.byKey(const Key('app-confirmation-confirm')),
      );
      expect(MediaQuery.textScalerOf(label).scale(16), 16 * layout.scale);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('app-confirmation-cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  }

  testWidgets('hugs short content and grows with content and text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _openConfirmation(
      tester,
      title: '안내',
      message: '확인했어요.',
      cancelLabel: '취소',
      confirmLabel: '확인',
    );
    final compact = _dialogRect(tester);
    expect(compact.width, lessThan(280));
    await tester.tap(find.byKey(const Key('app-confirmation-cancel')));
    await tester.pumpAndSettle();

    await _openConfirmation(
      tester,
      title: '안내',
      message: '확인했어요.',
      cancelLabel: '취소',
      confirmLabel: '확인',
      textScale: 2,
    );
    final enlarged = _dialogRect(tester);
    expect(enlarged.width, greaterThan(compact.width));
    expect(enlarged.height, greaterThan(compact.height));
    await tester.tap(find.byKey(const Key('app-confirmation-cancel')));
    await tester.pumpAndSettle();

    await _openConfirmation(tester);
    final longer = _dialogRect(tester);
    expect(longer.width, greaterThan(compact.width));
    expect(longer.width, lessThanOrEqualTo(400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wraps title, body and action labels at word boundaries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const title = '저장하지 않고 나갈까요?';
    const message = '저장하지 않은 변경 내용은 사라져요.';
    const confirmLabel = '재연결 초대 만들기';
    await _openConfirmation(
      tester,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      textScale: 2,
    );

    for (final original in [title, message, confirmLabel]) {
      final finder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.semanticsLabel == original,
      );
      expect(finder, findsOneWidget);
      final displayed = tester.widget<Text>(finder).data!;
      expect(displayed, contains('\n'));
      expect(displayed.split(RegExp(r'\s+')), original.split(' '));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      );
      for (final word in RegExp(r'\S+').allMatches(displayed)) {
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: word.start, extentOffset: word.end),
        );
        expect(boxes.map((box) => box.top).toSet(), hasLength(1));
      }
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

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
  String title = '수정 내용을 버릴까요?',
  String message = '저장하지 않은 변경 내용이 사라져요.',
  String confirmLabel = '수정 버리기',
  String cancelLabel = '계속 수정',
  ValueChanged<bool>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showAppConfirmationDialog(
                context: context,
                title: title,
                message: message,
                confirmLabel: confirmLabel,
                cancelLabel: cancelLabel,
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

Rect _dialogRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(Dialog), matching: find.byType(Material))
      .first,
);

class _RouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
