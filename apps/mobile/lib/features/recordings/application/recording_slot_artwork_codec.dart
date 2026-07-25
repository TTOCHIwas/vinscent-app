import 'dart:typed_data';

import '../../../core/drawing/app_drawing.dart';
import '../../../core/drawing/app_drawing_artifact_codec.dart';

typedef RecordingSlotArtworkArtifact = AppDrawingArtifact;

class RecordingSlotArtworkCodec {
  const RecordingSlotArtworkCodec({
    AppDrawingArtifactCodec codec = const AppDrawingArtifactCodec(),
  }) : _codec = codec;

  static const previewSize = AppDrawingArtifactCodec.previewSize;
  static const maxObjectBytes = AppDrawingArtifactCodec.maxObjectBytes;
  static const maxDecodedDrawingBytes =
      AppDrawingArtifactCodec.maxDecodedDrawingBytes;
  static const maxStrokeCount = AppDrawingArtifactCodec.maxStrokeCount;
  static const maxPointsPerStroke =
      AppDrawingArtifactCodec.maxPointsPerStroke;
  static const maxTotalPointCount = AppDrawingArtifactCodec.maxTotalPointCount;

  final AppDrawingArtifactCodec _codec;

  Future<RecordingSlotArtworkArtifact> encode(AppDrawingData drawing) {
    return _codec.encode(drawing);
  }

  Future<AppDrawingData> decodeDrawingData(Uint8List bytes) {
    return _codec.decodeDrawingData(bytes);
  }
}
