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
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextInputKeyboardAccessory(
            characterCount: 12,
            maxLength: 300,
            actionKey: const Key('test-text-action'),
            actionLabel: '저장',
            loadingLabel: '저장 중',
            enabled: true,
            isLoading: false,
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
