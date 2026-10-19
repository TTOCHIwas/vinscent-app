import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_input_style.dart';

void main() {
  test('keeps warm and green drawing text legible on the editing surface', () {
    for (final color in [
      const Color(0xFFF4932F),
      const Color(0xFF39B871),
      Colors.white,
    ]) {
      expect(AppInputStyle.contrastingBrightness(color), Brightness.dark);
    }
    expect(AppInputStyle.contrastingBrightness(Colors.black), Brightness.light);
  });
}
