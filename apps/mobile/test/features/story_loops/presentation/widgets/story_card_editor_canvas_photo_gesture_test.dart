import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_editor_session.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_editor_canvas.dart';

void main() {
  testWidgets('사진 칸 탭, 카드 유형 스와이프, 네컷 길게 눌러 이동을 구분한다', (
    tester,
  ) async {
    final image = await _solidImage();
    addTearDown(image.dispose);
    int? tappedIndex;
    int? typeStep;
    (int, int)? reordered;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 400,
              child: StoryCardEditorCanvas(
                backgroundImages: [image, image, image, image],
                scene: StoryCardScene.empty(
                  cardType: StoryCardType.fourCutGrid,
                ),
                visibleStrokes: const [],
                interactionMode: StoryCardEditorTool.background,
                onStrokeStart: (_, _) {},
                onStrokeUpdate: (_, _) {},
                onStrokeEnd: (_) {},
                onPhotoTapped: (index) => tappedIndex = index,
                onPhotosReordered: (from, to) => reordered = (from, to),
                onCardTypeStep: (step) => typeStep = step,
                onTextLayerScaleStart: (_, _) {},
                onTextLayerScaleUpdate: (_, _, _) {},
                onTextLayerScaleEnd: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final canvas = find.byType(StoryCardEditorCanvas);
    final rect = tester.getRect(canvas);
    await tester.tapAt(rect.topLeft + const Offset(70, 80));
    expect(tappedIndex, 0);

    await tester.drag(canvas, const Offset(-120, 0));
    await tester.pump();
    expect(typeStep, 1);

    final gesture = await tester.startGesture(
      rect.topLeft + const Offset(70, 80),
    );
    await tester.pump(const Duration(milliseconds: 520));
    await gesture.moveTo(rect.topLeft + const Offset(245, 80));
    await gesture.up();
    await tester.pump();
    expect(reordered, (0, 1));
  });
}

Future<ui.Image> _solidImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 20, 20),
    Paint()..color = Colors.red,
  );
  return recorder.endRecording().toImage(20, 20);
}
