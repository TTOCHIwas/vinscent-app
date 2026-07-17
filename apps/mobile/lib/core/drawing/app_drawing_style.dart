import 'dart:ui';

abstract final class AppDrawingStyle {
  static const colorPalette = <Color>[
    Color(0xFF111111),
    Color(0xFF6F737C),
    Color(0xFFFFFFFF),
    Color(0xFFE94B5F),
    Color(0xFFF4932F),
    Color(0xFFF7D748),
    Color(0xFF39B871),
    Color(0xFF3E8EDE),
    Color(0xFF8C5BEA),
    Color(0xFFE56BAA),
  ];

  static const thinStrokeWidth = 0.012;
  static const normalStrokeWidth = 0.022;
  static const thickStrokeWidth = 0.08;
  static const minStrokeWidth = thinStrokeWidth;
  static const maxStrokeWidth = thickStrokeWidth;
}
