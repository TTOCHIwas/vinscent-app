import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_card_network_image.dart';

void main() {
  test('selects a smaller image for a dense phone display', () {
    final transform = calendarCardPreviewTransform(
      sourceSize: const Size(800, 1000),
      maximumLogicalSize: const Size(46, 57.5),
      pixelRatio: 3,
    )!;

    expect(transform.width, 154);
    expect(transform.height, 192);
    expect(transform.resize, ResizeMode.contain);
  });

  test('retains the required tablet pixels and the card aspect ratio', () {
    final transform = calendarCardPreviewTransform(
      sourceSize: const Size(640, 1680),
      maximumLogicalSize: const Size(92, 241.5),
      pixelRatio: 2,
    )!;

    expect(transform.width, 196);
    expect(transform.height, 512);
    expect(transform.resize, ResizeMode.contain);
  });

  test('keeps original pixels when tablet demand is near the source', () {
    expect(
      calendarCardPreviewTransform(
        sourceSize: const Size(800, 1000),
        maximumLogicalSize: const Size(300, 375),
        pixelRatio: 3,
      ),
      isNull,
    );
  });
}
