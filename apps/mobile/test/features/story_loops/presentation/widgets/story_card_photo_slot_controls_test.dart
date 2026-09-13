import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_photo_slot_controls.dart';

void main() {
  testWidgets('선택한 빈 사진 칸 안에 촬영과 갤러리 동작을 표시한다', (tester) async {
    int? cameraIndex;
    int? galleryIndex;

    Widget subject({int? selectedEmptyIndex}) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: StoryCardPhotoSlotControls(
                cardType: StoryCardType.fourCutGrid,
                hasPhotos: const [true, false, false, false],
                selectedEmptyIndex: selectedEmptyIndex,
                onCameraPressed: (index) => cameraIndex = index,
                onGalleryPressed: (index) => galleryIndex = index,
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(subject());
    expect(find.byIcon(Icons.add), findsNothing);
    expect(
      find.byKey(const ValueKey('story-card-photo-slot-camera-1')),
      findsNothing,
    );

    await tester.pumpWidget(subject(selectedEmptyIndex: 1));
    expect(
      find.byKey(const ValueKey('story-card-photo-slot-camera-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('story-card-photo-slot-gallery-1')),
      findsOneWidget,
    );
    final camera = find.byKey(const ValueKey('story-card-photo-slot-camera-1'));
    final gallery = find.byKey(
      const ValueKey('story-card-photo-slot-gallery-1'),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: camera, matching: find.byType(Icon)),
          )
          .size,
      30,
    );
    expect(
      tester.getCenter(gallery).dx - tester.getCenter(camera).dx,
      greaterThanOrEqualTo(64),
    );

    await tester.tap(camera);
    await tester.tap(gallery);
    expect(cameraIndex, 1);
    expect(galleryIndex, 1);
  });
}
