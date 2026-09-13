import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_photo_adjustment_screen.dart';

void main() {
  testWidgets('사진 조정 화면은 대상 비율 가이드와 필터 및 제거 동작을 제공한다', (
    tester,
  ) async {
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
    await tester.pumpAndSettle();

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
}
