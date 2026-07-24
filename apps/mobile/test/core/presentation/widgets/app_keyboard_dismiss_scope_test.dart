import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_keyboard_dismiss_scope.dart';

void main() {
  testWidgets('unfocuses a text field after a touch outside it', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardDismissScope(
          child: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                Expanded(
                  child: GestureDetector(
                    key: const Key('outside-input'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.byKey(const Key('outside-input')));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('keeps focus for controls in the same text field tap region', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardDismissScope(
          child: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                TextFieldTapRegion(
                  child: TextButton(
                    key: const Key('editing-control'),
                    onPressed: () => pressed = true,
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.byKey(const Key('editing-control')));
    await tester.pump();

    expect(pressed, isTrue);
    expect(focusNode.hasFocus, isTrue);
  });
}
