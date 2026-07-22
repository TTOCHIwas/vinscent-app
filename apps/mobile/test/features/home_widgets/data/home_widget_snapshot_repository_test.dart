import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_partner_card_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot_repository.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';

void main() {
  test(
    'preserves only the source that failed while updating other assets',
    () async {
      final updatedAt = DateTime.utc(2026, 7, 22);
      final loader = HomeWidgetSnapshotAssetLoader(
        characterRepository: _CharacterRepository(
          CoupleCharacter(
            coupleId: 'couple-id',
            imagePath: 'character.png',
            drawingDataPath: 'character.json',
            imageUrl: 'https://example.com/character.png',
            createdAt: updatedAt,
            updatedAt: updatedAt,
          ),
        ),
        recordingRepository: _FailingRecordingRepository(),
        partnerCardRepository: _PartnerCardRepository(
          HomeWidgetPartnerCard(
            id: 'card-id',
            previewUrl: 'https://example.com/card.png',
            revision: 2,
            updatedAt: updatedAt,
          ),
        ),
      );

      final snapshot = await loader.fetch(
        coupleId: 'couple-id',
        currentUserId: 'user-id',
      );

      expect(snapshot.characterImage.type, HomeWidgetAssetUpdateType.replace);
      expect(snapshot.recordingAudio.type, HomeWidgetAssetUpdateType.preserve);
      expect(snapshot.partnerCardImage.type, HomeWidgetAssetUpdateType.replace);
      expect(snapshot.requiresRetry, isTrue);
    },
  );
}

class _CharacterRepository extends Fake implements CoupleCharacterRepository {
  _CharacterRepository(this.character);

  final CoupleCharacter? character;

  @override
  Future<CoupleCharacter?> fetchCurrentCharacter() async => character;
}

class _FailingRecordingRepository extends Fake
    implements CoupleRecordingRepository {
  @override
  Future<CoupleRecordingOverview> fetchOverview() {
    throw StateError('temporary recording failure');
  }
}

class _PartnerCardRepository implements HomeWidgetPartnerCardRepository {
  const _PartnerCardRepository(this.card);

  final HomeWidgetPartnerCard? card;

  @override
  Future<HomeWidgetPartnerCard?> fetchLatestPartnerCard({
    required String coupleId,
    required String currentUserId,
  }) async {
    return card;
  }
}
