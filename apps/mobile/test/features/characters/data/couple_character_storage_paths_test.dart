import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';

void main() {
  const coupleId = '20000000-0000-0000-0000-000000000001';
  const artifactRevision = '30000000-0000-0000-0000-000000000001';

  test('character artifacts use a shared immutable revision directory', () {
    expect(
      CoupleCharacterStoragePaths.imageRevisionPathFor(
        coupleId,
        artifactRevision,
      ),
      '$coupleId/revisions/$artifactRevision/preview.png',
    );
    expect(
      CoupleCharacterStoragePaths.drawingDataRevisionPathFor(
        coupleId,
        artifactRevision,
      ),
      '$coupleId/revisions/$artifactRevision/drawing.json',
    );
  });

  test('legacy fixed paths remain available for existing characters', () {
    expect(
      CoupleCharacterStoragePaths.imagePathFor(coupleId),
      '$coupleId/current.png',
    );
    expect(
      CoupleCharacterStoragePaths.drawingDataPathFor(coupleId),
      '$coupleId/current.json',
    );
  });
}
