class CoupleCalendarEventArtworkPath {
  CoupleCalendarEventArtworkPath({
    required String coupleId,
    required String eventId,
    required String artifactId,
  }) : coupleId = _validateSegment(coupleId, 'coupleId'),
       eventId = _validateSegment(eventId, 'eventId'),
       artifactId = _validateSegment(artifactId, 'artifactId');

  static const bucketId = 'couple-calendar-artworks';

  final String coupleId;
  final String eventId;
  final String artifactId;

  String get directory => '$coupleId/events/$eventId/artworks/$artifactId';

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
