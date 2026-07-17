class RecordingSlotArtworkPath {
  RecordingSlotArtworkPath({
    required String coupleId,
    required String slotId,
    required String artifactId,
  }) : coupleId = _validateSegment(coupleId, 'coupleId'),
       slotId = _validateSegment(slotId, 'slotId'),
       artifactId = _validateSegment(artifactId, 'artifactId');

  static const bucketId = 'couple-recording-artworks';

  final String coupleId;
  final String slotId;
  final String artifactId;

  String get directory => '$coupleId/slots/$slotId/artworks/$artifactId';

  String get previewPath => '$directory/preview.webp';

  String get drawingDataPath => '$directory/drawing.json.gz';

  static String _validateSegment(String value, String name) {
    if (value.isEmpty ||
        value == '.' ||
        value == '..' ||
        value.contains('/') ||
        value.contains('\\')) {
      throw ArgumentError.value(value, name, 'must be one storage segment');
    }
    return value;
  }
}
