import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_color_sampler.dart';

void main() {
  const canvasRect = Rect.fromLTWH(10, 20, 100, 200);
  final sample = StoryCardColorSampleBuffer(
    width: 2,
    height: 2,
    rgbaBytes: Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      0,
      255,
      255,
      255,
      255,
      255,
      255,
    ]),
  );

  test('samples colors using coordinates relative to the card canvas', () {
    expect(
      sample.colorAt(position: const Offset(10, 20), canvasRect: canvasRect),
      const Color(0xFFFF0000),
    );
    expect(
      sample.colorAt(position: const Offset(109, 20), canvasRect: canvasRect),
      const Color(0xFF00FF00),
    );
    expect(
      sample.colorAt(position: const Offset(10, 219), canvasRect: canvasRect),
      const Color(0xFF0000FF),
    );
    expect(
      sample.colorAt(position: const Offset(109, 219), canvasRect: canvasRect),
      const Color(0xFFFFFFFF),
    );
  });

  test('clamps pointer positions to the card canvas', () {
    expect(
      sample.colorAt(position: const Offset(-50, -50), canvasRect: canvasRect),
      const Color(0xFFFF0000),
    );
    expect(
      sample.colorAt(position: const Offset(500, 500), canvasRect: canvasRect),
      const Color(0xFFFFFFFF),
    );
  });

  test('rejects malformed pixel buffers', () {
    expect(
      () => StoryCardColorSampleBuffer(
        width: 2,
        height: 2,
        rgbaBytes: Uint8List(4),
      ),
      throwsArgumentError,
    );
  });
}
