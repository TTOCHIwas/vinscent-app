import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_action_button.dart';
import 'package:vinscent/core/presentation/widgets/app_action_tone.dart';
import 'package:vinscent/core/theme/app_colors.dart';

void main() {
  testWidgets('keeps neutral actions as the default', (tester) async {
    await _pumpButton(tester, tone: AppActionTone.neutral);

    expect(_material(tester).color, AppColors.actionPrimary);
    expect(_label(tester).style?.color, AppColors.textInverse);
  });

  testWidgets('uses the brand palette only when explicitly requested', (
    tester,
  ) async {
    await _pumpButton(tester, tone: AppActionTone.brand);

    expect(_material(tester).color, AppColors.brandAction);
    expect(_label(tester).style?.color, AppColors.onBrandAction);
    expect(
      _inkWell(tester).overlayColor?.resolve({WidgetState.pressed}),
      AppColors.brandPressed,
    );
  });

  testWidgets('preserves the disabled appearance for brand actions', (
    tester,
  ) async {
    await _pumpButton(tester, tone: AppActionTone.brand, enabled: false);

    expect(_material(tester).color, AppColors.actionDisabled);
    expect(_label(tester).style?.color, AppColors.actionDisabledContent);
  });
}

Future<void> _pumpButton(
  WidgetTester tester, {
  required AppActionTone tone,
  bool enabled = true,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppActionButton(
          key: const Key('action'),
          label: '계속',
          enabled: enabled,
          tone: tone,
          onPressed: () {},
        ),
      ),
    ),
  );
}

Material _material(WidgetTester tester) {
  return tester.widget<Material>(
    find.descendant(
      of: find.byKey(const Key('action')),
      matching: find.byType(Material),
    ),
  );
}

InkWell _inkWell(WidgetTester tester) {
  return tester.widget<InkWell>(
    find.descendant(
      of: find.byKey(const Key('action')),
      matching: find.byType(InkWell),
    ),
  );
}

Text _label(WidgetTester tester) {
  return tester.widget<Text>(
    find.descendant(
      of: find.byKey(const Key('action')),
      matching: find.text('계속'),
    ),
  );
}
