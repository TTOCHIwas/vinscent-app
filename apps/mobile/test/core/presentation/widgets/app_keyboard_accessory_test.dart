import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_keyboard_accessory.dart';

void main() {
  testWidgets('hides the accessory while the keyboard is closed', (
    tester,
  ) async {
    await _pump(tester, keyboardInset: 0, isActive: true);

    expect(find.byKey(const Key('test-keyboard-accessory')), findsNothing);
  });

  testWidgets('hides the accessory while its input is inactive', (
    tester,
  ) async {
    await _pump(tester, keyboardInset: 300, isActive: false);

    expect(find.byKey(const Key('test-keyboard-accessory')), findsNothing);
  });

  testWidgets('places the accessory directly above the actual keyboard', (
    tester,
  ) async {
    await _pump(tester, keyboardInset: 300, isActive: true);

    final accessory = find.byKey(const Key('test-keyboard-accessory'));
    expect(accessory, findsOneWidget);
    expect(tester.getRect(accessory).bottom, 400);
  });

  testWidgets('reacts when the keyboard opens after the first layout', (
    tester,
  ) async {
    await _pump(tester, keyboardInset: 0, isActive: true);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    final accessory = find.byKey(const Key('test-keyboard-accessory'));
    expect(accessory, findsOneWidget);
    expect(tester.getRect(accessory).bottom, 400);
  });

  testWidgets('shows a reusable character count and text action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextInputKeyboardAccessory(
            characterCount: 12,
            maxLength: 300,
            characterCountKey: const Key('test-character-count'),
            actionKey: const Key('test-text-action'),
            actionLabel: '저장',
            loadingLabel: '저장 중',
            enabled: true,
            isLoading: false,
            horizontalPadding: 12,
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('12 / 300'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test-text-action')));

    expect(pressed, isTrue);
  });

  testWidgets('aligns the visible count and action to equal side margins', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextInputKeyboardAccessory(
            characterCount: 12,
            maxLength: 300,
            characterCountKey: const Key('test-character-count'),
            actionKey: const Key('test-text-action'),
            actionLabel: '저장',
            loadingLabel: '저장 중',
            enabled: true,
            isLoading: false,
            horizontalPadding: 12,
            onPressed: () {},
          ),
        ),
      ),
    );

    final countText = find.descendant(
      of: find.byKey(const Key('test-character-count')),
      matching: find.text('12 / 300'),
    );
    final actionText = find.descendant(
      of: find.byKey(const Key('test-text-action')),
      matching: find.byType(Text),
    );
    final surfaceWidth = tester.getSize(find.byType(Scaffold)).width;

    expect(
      tester.getRect(countText).left,
      closeTo(surfaceWidth - tester.getRect(actionText).right, 0.5),
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required double keyboardInset,
  required bool isActive,
}) async {
  tester.view.physicalSize = const Size(400, 700);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppKeyboardAccessoryLayout(
          isActive: isActive,
          accessory: const SizedBox(
            key: Key('test-keyboard-accessory'),
            height: 52,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
  await tester.pump();
}
