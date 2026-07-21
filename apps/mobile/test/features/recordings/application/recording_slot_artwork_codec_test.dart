import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/core/drawing/app_drawing.dart';
import 'package:vinscent/features/recordings/application/recording_slot_artwork_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'encodes a transparent lossless WebP preview and gzip drawing data',
    () async {
      const drawing = AppDrawingData(
        strokes: [
          AppDrawingStroke(
            tool: AppDrawingTool.pen,
            color: Color(0xFFE94B5F),
            width: 0.022,
            points: [
              AppDrawingPoint(x: 0.2, y: 0.3),
              AppDrawingPoint(x: 0.8, y: 0.7),
            ],
          ),
        ],
      );

      final artifact = await const RecordingSlotArtworkCodec().encode(drawing);
      final decodedPreview = image.decodeWebP(artifact.previewBytes);
      final decodedDrawing = await const RecordingSlotArtworkCodec()
          .decodeDrawingData(artifact.drawingDataBytes);

      expect(decodedPreview, isNotNull);
      expect(decodedPreview!.width, RecordingSlotArtworkCodec.previewSize);
      expect(decodedPreview.height, RecordingSlotArtworkCodec.previewSize);
      expect(decodedPreview.numChannels, 4);
      expect(artifact.previewBytes.length, lessThanOrEqualTo(256 * 1024));
      expect(artifact.drawingDataBytes.length, lessThanOrEqualTo(256 * 1024));
      expect(decodedDrawing.strokes, hasLength(1));
      expect(decodedDrawing.strokes.single.tool, AppDrawingTool.pen);
      expect(decodedDrawing.strokes.single.color, const Color(0xFFE94B5F));
      expect(decodedDrawing.strokes.single.points, hasLength(2));
    },
  );

  test('rejects an empty drawing', () async {
    expect(
      () => const RecordingSlotArtworkCodec().encode(AppDrawingData.empty()),
      throwsStateError,
    );
  });

  test('rejects drawing data that expands beyond the decoded limit', () async {
    final bytes = _gzipJson({
      'version': 1,
      'strokes': const <Object>[],
      'padding': 'a' * RecordingSlotArtworkCodec.maxDecodedDrawingBytes,
    });

    expect(
      () => const RecordingSlotArtworkCodec().decodeDrawingData(bytes),
      throwsFormatException,
    );
  });

  test('rejects a stroke with too many points', () async {
    final points = List.generate(
      RecordingSlotArtworkCodec.maxPointsPerStroke + 1,
      (index) => {'x': 0.5, 'y': 0.5},
    );
    final bytes = _gzipJson({
      'version': 1,
      'strokes': [
        {'tool': 'pen', 'color': '#ffffffff', 'width': 0.022, 'points': points},
      ],
    });

    expect(
      () => const RecordingSlotArtworkCodec().decodeDrawingData(bytes),
      throwsFormatException,
    );
  });

  test('rejects drawing points outside normalized canvas bounds', () async {
    final bytes = _gzipJson({
      'version': 1,
      'strokes': [
        {
          'tool': 'pen',
          'color': '#ffffffff',
          'width': 0.022,
          'points': [
            {'x': 1.01, 'y': 0.5},
          ],
        },
      ],
    });

    expect(
      () => const RecordingSlotArtworkCodec().decodeDrawingData(bytes),
      throwsFormatException,
    );
  });
}

Uint8List _gzipJson(Map<String, Object> value) {
  return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(value))));
}
