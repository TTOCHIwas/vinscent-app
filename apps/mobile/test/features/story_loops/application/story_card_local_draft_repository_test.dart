import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_local_draft_repository.dart';
import 'package:vinscent/features/story_loops/data/story_card_draft.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';

void main() {
  late Directory cacheDirectory;
  late DateTime now;
  late FileStoryCardLocalDraftRepository repository;

  setUp(() async {
    cacheDirectory = await Directory.systemTemp.createTemp(
      'vinscent-story-card-drafts-',
    );
    now = DateTime.utc(2026, 9, 13, 12);
    repository = FileStoryCardLocalDraftRepository(
      cacheDirectoryLoader: () async => cacheDirectory,
      now: () => now,
      idFactory: () => 'draft-1',
    );
  });

  tearDown(() async {
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  });

  test('stores a local draft for exactly 72 hours and takes it once', () async {
    final draft = StoryCardDraft(
      scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
      backgroundImageBytes: Uint8List.fromList([1, 2, 3]),
    );

    final saved = await repository.save(
      draft: draft,
      previewImageBytes: Uint8List.fromList([9, 8, 7]),
    );

    expect(saved.savedAt, now);
    expect(saved.expiresAt, now.add(const Duration(hours: 72)));
    expect((await repository.list()).single.previewImageBytes, [9, 8, 7]);

    final taken = await repository.take(saved.id);

    expect(taken?.scene.cardType, StoryCardType.fullBleed);
    expect(taken?.backgroundImageBytes, [1, 2, 3]);
    expect(await repository.list(), isEmpty);
    expect(await repository.take(saved.id), isNull);
  });

  test('prunes a draft when its 72-hour retention has elapsed', () async {
    final saved = await repository.save(
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
        backgroundImageBytes: Uint8List.fromList([1]),
      ),
      previewImageBytes: Uint8List.fromList([2]),
    );

    now = now.add(const Duration(hours: 72));

    expect(await repository.list(), isEmpty);
    expect(await repository.take(saved.id), isNull);
  });

  test('saving a loaded draft starts a fresh retention window', () async {
    final first = await repository.save(
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
        backgroundImageBytes: Uint8List.fromList([1]),
      ),
      previewImageBytes: Uint8List.fromList([2]),
    );
    now = now.add(const Duration(hours: 48));
    final loaded = await repository.take(first.id);
    expect(loaded, isNotNull);

    final resaved = await repository.save(
      draft: loaded!,
      previewImageBytes: Uint8List.fromList([3]),
    );

    expect(resaved.savedAt, now);
    expect(resaved.expiresAt, now.add(const Duration(hours: 72)));
  });

  test('prunes an abandoned atomic-writing directory', () async {
    final writingDirectory = Directory(
      '${cacheDirectory.path}${Platform.pathSeparator}'
      'story_card_drafts${Platform.pathSeparator}abandoned.writing',
    );
    await writingDirectory.create(recursive: true);
    await File(
      '${writingDirectory.path}${Platform.pathSeparator}photo_0.bin',
    ).writeAsBytes([1, 2, 3]);

    expect(await repository.list(), isEmpty);
    expect(await writingDirectory.exists(), isFalse);
  });
}
