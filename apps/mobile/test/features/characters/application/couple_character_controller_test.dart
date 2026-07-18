import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';

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

  test('기본 캐릭터를 저장하면 로컬 커플 설정 상태를 즉시 동기화한다', () async {
    final characterRepository = _FakeCoupleCharacterRepository(null);
    final coupleRepository = _FakeCoupleRepository(
      activeCouple(characterSetupStatus: CoupleCharacterSetupStatus.custom),
    );
    final container = _container(
      couple: activeCouple(
        characterSetupStatus: CoupleCharacterSetupStatus.defaultCharacter,
      ),
      repository: characterRepository,
      coupleRepository: coupleRepository,
    );
    addTearDown(container.dispose);

    await container.read(coupleCharacterControllerProvider.future);
    await container
        .read(coupleCharacterControllerProvider.notifier)
        .saveCharacter(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          drawingDataJson: '{"strokes":[]}',
        );

    expect(characterRepository.saveCount, 1);
    expect(coupleRepository.fetchCount, 1);
    expect(
      container.read(coupleControllerProvider).requireValue?.hasCustomCharacter,
      isTrue,
    );
  });
}

ProviderContainer _container({
  required Couple couple,
  required CoupleCharacterRepository repository,
  CoupleRepository? coupleRepository,
}) {
  return ProviderContainer(
    overrides: [
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => couple,
      ),
      coupleCharacterRepositoryProvider.overrideWithValue(repository),
      if (coupleRepository != null)
        coupleRepositoryProvider.overrideWithValue(coupleRepository),
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

  CoupleCharacter? character;
  int fetchCount = 0;
  int saveCount = 0;

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
  }) async {
    saveCount += 1;
    return character = _character();
  }
}

class _FakeCoupleRepository implements CoupleRepository {
  _FakeCoupleRepository(this.couple);

  final Couple couple;
  int fetchCount = 0;

  @override
  Future<Couple?> fetchCurrentCouple() async {
    fetchCount += 1;
    return couple;
  }

  @override
  Future<Couple> createInvite() => throw UnimplementedError();

  @override
  Future<Couple> joinByCode(String inviteCode) => throw UnimplementedError();

  @override
  Future<Couple?> cancelInvite() => throw UnimplementedError();

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) =>
      throw UnimplementedError();

  @override
  Future<Couple> useDefaultCharacter() => throw UnimplementedError();

  @override
  Future<Couple> disconnectCouple() => throw UnimplementedError();

  @override
  Future<void> deleteDisconnectedArchiveNow() => throw UnimplementedError();
}
