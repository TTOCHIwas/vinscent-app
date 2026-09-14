import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_hsv_color_picker_sheet.dart';

void main() {
  testWidgets('HSV 선택기는 전체 색상에서 고른 값을 적용한다', (tester) async {
    Color? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selected = await showAppHsvColorPickerSheet(
                context: context,
                initialColor: Colors.white,
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('app-hsv-color-picker-sheet')),
      findsOneWidget,
    );

    final hueRect = tester.getRect(
      find.byKey(const ValueKey('app-hsv-color-picker-hue')),
    );
    await tester.tapAt(hueRect.centerRight - const Offset(2, 0));
    await tester.pump();
    final fieldRect = tester.getRect(
      find.byKey(const ValueKey('app-hsv-color-picker-field')),
    );
    await tester.dragFrom(
      fieldRect.center,
      Offset(fieldRect.width * 0.2, -fieldRect.height * 0.2),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('app-hsv-color-picker-apply')));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected, isNot(Colors.white));
  });
}
