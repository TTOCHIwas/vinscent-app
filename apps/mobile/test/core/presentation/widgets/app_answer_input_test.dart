import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_answer_input.dart';
import 'package:vinscent/core/theme/app_theme.dart';
import 'package:vinscent/core/theme/app_input_style.dart';
import 'package:vinscent/features/profile/presentation/widgets/profile_display_name_field.dart';

void main() {
  testWidgets('uses neutral focus and selection colors while editing', (
    tester,
  ) async {
    final controller = TextEditingController(text: '함께 쉬는 시간');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: AppAnswerInput(controller: controller)),
      ),
    );
    await tester.tap(find.byType(CupertinoTextField));
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
    await tester.pump();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.cursorColor, AppInputStyle.focusColor);
    expect(editable.selectionColor, AppInputStyle.selectionColor);
    expect(editable.cursorColor.r, editable.cursorColor.g);
    expect(editable.cursorColor.g, editable.cursorColor.b);
    expect(
      AppTheme.light.textSelectionTheme.selectionHandleColor,
      AppInputStyle.focusColor,
    );
  });

  testWidgets('keeps writing decoration stable when focus changes', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppAnswerInput(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: 5,
            enforceMaxLength: false,
          ),
        ),
      ),
    );
    final field = find.byType(CupertinoTextField);
    expect(tester.widget<CupertinoTextField>(field).decoration, isNull);
    await tester.enterText(field, '같이\n산책하기');
    await tester.pump();
    expect(controller.text, '같이\n산책하기');
    expect(tester.widget<CupertinoTextField>(field).decoration, isNull);
    expect(
      tester.widget<CupertinoTextField>(field).maxLengthEnforcement,
      MaxLengthEnforcement.none,
    );
  });

  testWidgets('keeps nickname clear and valid submit actions', (tester) async {
    var value = '또치';
    var clearCount = 0;
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ProfileDisplayNameField(
              value: value,
              isValid: value.length >= 2,
              onChanged: (next) => setState(() => value = next),
              onClear: () => setState(() {
                value = '';
                clearCount++;
              }),
              onSubmitted: () => submitted = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('입력 지우기'));
    await tester.pump();
    expect(clearCount, 1);
    expect(value, isEmpty);
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(find.byType(CupertinoTextField), '초코');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(submitted, isTrue);
  });
}
