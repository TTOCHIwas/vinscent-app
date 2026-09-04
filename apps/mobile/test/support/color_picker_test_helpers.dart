import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/widgets/app_color_sampler.dart';

Future<AppColorSampler> openColorPicker(
  WidgetTester tester, {
  required String buttonPrefix,
  String? overlayPrefix,
}) async {
  await tester.tap(find.byKey(ValueKey('$buttonPrefix-eyedropper')));
  final sampler = find.byKey(
    ValueKey('${overlayPrefix ?? buttonPrefix}-eyedropper-overlay'),
  );
  for (var attempt = 0; attempt < 40 && sampler.evaluate().isEmpty; attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
  await tester.pumpAndSettle();
  expect(sampler, findsOneWidget);
  return tester.widget<AppColorSampler>(sampler);
}
