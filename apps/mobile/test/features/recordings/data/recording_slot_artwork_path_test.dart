import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/data/recording_slot_artwork_path.dart';

void main() {
  group('RecordingSlotArtworkPath', () {
    test('creates immutable preview and drawing paths for one artifact', () {
      final path = RecordingSlotArtworkPath(
        coupleId: 'couple-1',
        slotId: 'slot-2',
        artifactId: 'artifact-3',
      );

      expect(
        path.previewPath,
        'couple-1/slots/slot-2/artworks/artifact-3/preview.webp',
      );
      expect(
        path.drawingDataPath,
        'couple-1/slots/slot-2/artworks/artifact-3/drawing.json.gz',
      );
    });

    test('rejects path segments that can escape their storage directory', () {
      expect(
        () => RecordingSlotArtworkPath(
          coupleId: '../couple',
          slotId: 'slot-2',
          artifactId: 'artifact-3',
        ),
        throwsArgumentError,
      );
      expect(
        () => RecordingSlotArtworkPath(
          coupleId: 'couple-1',
          slotId: 'slot/2',
          artifactId: 'artifact-3',
        ),
        throwsArgumentError,
      );
      expect(
        () => RecordingSlotArtworkPath(
          coupleId: 'couple-1',
          slotId: 'slot-2',
          artifactId: '',
        ),
        throwsArgumentError,
      );
    });
  });
}
