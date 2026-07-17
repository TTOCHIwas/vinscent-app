import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('보관 중인 커플의 캐릭터를 조회한다', () async {
    final character = _character();
    final repository = _FakeCoupleCharacterRepository(character);
    final container = _container(
      couple: archivedReadOnlyCouple(),
      repository: repository,
    );
    addTearDown(container.dispose);

    final result = await container.read(
      coupleCharacterControllerProvider.future,
    );

    expect(result, same(character));
    expect(repository.fetchCount, 1);
  });

  test('대기 중인 커플은 캐릭터를 조회하지 않는다', () async {
    final repository = _FakeCoupleCharacterRepository(_character());
    final container = _container(
      couple: pendingCouple(),
      repository: repository,
    );
    addTearDown(container.dispose);

    final result = await container.read(
      coupleCharacterControllerProvider.future,
    );

    expect(result, isNull);
    expect(repository.fetchCount, 0);
  });
}

ProviderContainer _container({
  required Couple couple,
  required CoupleCharacterRepository repository,
}) {
  return ProviderContainer(
    overrides: [
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => couple,
      ),
      coupleCharacterRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

CoupleCharacter _character() {
  return CoupleCharacter(
    coupleId: 'couple-id',
    imagePath: CoupleCharacterStoragePaths.imagePathFor('couple-id'),
    drawingDataPath: CoupleCharacterStoragePaths.drawingDataPathFor(
      'couple-id',
    ),
    updatedBy: 'user-id',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    imageUrl: 'https://example.com/current.png',
  );
}

class _FakeCoupleCharacterRepository implements CoupleCharacterRepository {
  _FakeCoupleCharacterRepository(this.character);

  final CoupleCharacter? character;
  int fetchCount = 0;

  @override
  Future<CoupleCharacter?> fetchCurrentCharacter() async {
    fetchCount += 1;
    return character;
  }

  @override
  Future<String?> fetchDrawingData(CoupleCharacter character) async => null;

  @override
  Future<CoupleCharacter> saveCharacter({
    required String coupleId,
    required Uint8List imageBytes,
    required String drawingDataJson,
  }) {
    throw UnsupportedError('saveCharacter is not used in this test');
  }
}
