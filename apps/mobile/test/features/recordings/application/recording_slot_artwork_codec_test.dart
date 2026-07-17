import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/characters/data/character_drawing.dart';
import 'package:vinscent/features/recordings/application/recording_slot_artwork_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('encodes a transparent lossless WebP preview and gzip drawing data', () async {
    const drawing = CharacterDrawingData(
      strokes: [
        CharacterDrawingStroke(
          tool: CharacterDrawingTool.pen,
          color: Color(0xFFE94B5F),
          width: 0.022,
          points: [
            CharacterDrawingPoint(x: 0.2, y: 0.3),
            CharacterDrawingPoint(x: 0.8, y: 0.7),
          ],
        ),
      ],
    );

    final artifact = await const RecordingSlotArtworkCodec().encode(drawing);
    final decodedPreview = image.decodeWebP(artifact.previewBytes);
    final decodedDrawing = const RecordingSlotArtworkCodec().decodeDrawingData(
      artifact.drawingDataBytes,
    );

    expect(decodedPreview, isNotNull);
    expect(decodedPreview!.width, RecordingSlotArtworkCodec.previewSize);
    expect(decodedPreview.height, RecordingSlotArtworkCodec.previewSize);
    expect(decodedPreview.numChannels, 4);
    expect(artifact.previewBytes.length, lessThanOrEqualTo(256 * 1024));
    expect(artifact.drawingDataBytes.length, lessThanOrEqualTo(256 * 1024));
    expect(decodedDrawing.strokes, hasLength(1));
    expect(decodedDrawing.strokes.single.tool, CharacterDrawingTool.pen);
    expect(decodedDrawing.strokes.single.color, const Color(0xFFE94B5F));
    expect(decodedDrawing.strokes.single.points, hasLength(2));
  });

  test('rejects an empty drawing', () async {
    expect(
      () => const RecordingSlotArtworkCodec().encode(
        CharacterDrawingData.empty(),
      ),
      throwsStateError,
    );
  });
}
