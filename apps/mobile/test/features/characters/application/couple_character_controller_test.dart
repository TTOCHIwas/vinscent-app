import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/characters/presentation/widgets/couple_character_avatar.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';

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
    expect(repository.includeImageUrls, [false]);
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

  test('카메라 효과용 캐릭터 이미지 바이트를 저장소에서 조회한다', () async {
    final repository = _FakeCoupleCharacterRepository(_character())
      ..imageBytes = Uint8List.fromList([4, 5, 6]);
    final container = _container(
      couple: activeCouple(),
      repository: repository,
    );
    addTearDown(container.dispose);

    final character = await container.read(
      coupleCharacterControllerProvider.future,
    );
    final result = await container
        .read(coupleCharacterControllerProvider.notifier)
        .fetchImageBytes(character!);

    expect(result, [4, 5, 6]);
    expect(repository.imageFetchCount, 1);
  });

  testWidgets('서명 URL 없이 저장소의 캐릭터 이미지를 표시한다', (tester) async {
    final date = DateTime.utc(2026);
    final repository = _FakeCoupleCharacterRepository(
      _character(includeUrl: false),
    )..imageBytes = (await tester.runAsync(_png))!;

    final container = ProviderContainer(
      overrides: [
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => UserProfile(
            id: 'direct-character-test',
            displayName: '테스트',
            birthDate: DateTime(1990),
            onboardingCompletedAt: date,
            createdAt: date,
            updatedAt: date,
          ),
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(),
        ),
        coupleCharacterRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profileControllerProvider.future);
    await container.read(coupleCharacterControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CoupleCharacterAvatar()),
      ),
    );
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    await tester.runAsync(() async {
      final result = Completer<void>();
      final stream = image.image.resolve(const ImageConfiguration());
      final listener = ImageStreamListener(
        (image, _) {
          image.dispose();
          if (!result.isCompleted) result.complete();
        },
        onError: (error, stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      );
      stream.addListener(listener);
      try {
        await result.future.timeout(const Duration(seconds: 5));
      } finally {
        stream.removeListener(listener);
      }
    });
    await tester.pumpAndSettle();

    expect(find.byType(RawImage), findsOneWidget);
    expect(repository.includeImageUrls, [false]);
    expect(repository.imageFetchCount, 1);
  });
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.black, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
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

CoupleCharacter _character({bool includeUrl = true}) {
  return CoupleCharacter(
    coupleId: 'couple-id',
    imagePath: CoupleCharacterStoragePaths.imagePathFor('couple-id'),
    drawingDataPath: CoupleCharacterStoragePaths.drawingDataPathFor(
      'couple-id',
    ),
    updatedBy: 'user-id',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    imageUrl: includeUrl ? 'https://example.com/current.png' : null,
  );
}

class _FakeCoupleCharacterRepository implements CoupleCharacterRepository {
  _FakeCoupleCharacterRepository(this.character);

  CoupleCharacter? character;
  int fetchCount = 0;
  final includeImageUrls = <bool>[];
  int saveCount = 0;
  int imageFetchCount = 0;
  Uint8List imageBytes = Uint8List(0);

  @override
  Future<CoupleCharacter?> fetchCurrentCharacter({
    bool includeImageUrl = true,
  }) async {
    fetchCount += 1;
    includeImageUrls.add(includeImageUrl);
    return character;
  }

  @override
  Future<String?> fetchDrawingData(CoupleCharacter character) async => null;

  @override
  Future<Uint8List> fetchImageBytes(CoupleCharacter character) async {
    imageFetchCount += 1;
    return imageBytes;
  }

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
  Future<void> cancelInitialSetup() => throw UnimplementedError();

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
