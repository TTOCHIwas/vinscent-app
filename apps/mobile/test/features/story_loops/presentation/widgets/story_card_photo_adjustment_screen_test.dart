import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_photo_adjustment_screen.dart';

void main() {
  testWidgets('사진 조정 화면은 대상 비율 가이드와 필터 및 제거 동작을 제공한다', (tester) async {
    StoryCardBackgroundTransform? savedTransform;
    StoryCardFilmState? savedFilm;
    var removed = false;
    final source = image.Image(width: 40, height: 30);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryCardPhotoAdjustmentScreen(
          imageBytes: Uint8List.fromList(image.encodeJpg(source)),
          cropAspectRatio: 2,
          initialTransform: const StoryCardBackgroundTransform.initial(),
          initialFilm: const StoryCardFilmState.original(),
          onBack: () {},
          onDone: (transform, film) {
            savedTransform = transform;
            savedFilm = film;
          },
          onRemove: () => removed = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final cropFrame = find.byKey(
      const ValueKey('story-card-photo-adjustment-crop-frame'),
    );
    expect(cropFrame, findsOneWidget);
    expect(tester.getSize(cropFrame).aspectRatio, closeTo(2, 0.01));
    expect(
      find.byKey(const ValueKey('story-card-photo-adjustment-filter')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('story-card-photo-adjustment-film-warmth')),
    );
    await tester.tap(
      find.byKey(const ValueKey('story-card-photo-adjustment-done')),
    );
    expect(savedTransform, isNotNull);
    expect(savedFilm?.look, StoryCardFilmLook.warmth);

    await tester.tap(
      find.byKey(const ValueKey('story-card-photo-adjustment-remove')),
    );
    expect(removed, isTrue);
  });

  testWidgets('사진 이동 확대 회전 값을 함께 적용한다', (tester) async {
    StoryCardBackgroundTransform? savedTransform;
    final source = image.Image(width: 40, height: 30);

    await tester.pumpWidget(
      MaterialApp(
        home: StoryCardPhotoAdjustmentScreen(
          imageBytes: Uint8List.fromList(image.encodeJpg(source)),
          cropAspectRatio: 1,
          initialTransform: const StoryCardBackgroundTransform.initial(),
          initialFilm: const StoryCardFilmState.original(),
          onBack: () {},
          onDone: (transform, _) => savedTransform = transform,
          onRemove: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    final gestureTarget = find.byKey(
      const ValueKey('story-card-photo-adjustment-gesture'),
    );
    final center = tester.getCenter(gestureTarget);
    final first = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveTo(center + const Offset(-40, 30));
    await second.moveTo(center + const Offset(80, 70));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('story-card-photo-adjustment-done')),
    );

    expect(savedTransform, isNotNull);
    expect(savedTransform!.scale, greaterThan(1));
    expect(savedTransform!.offsetX, isNot(0));
    expect(savedTransform!.offsetY, isNot(0));
    expect(savedTransform!.rotation.abs(), greaterThan(0.1));
  });
}
