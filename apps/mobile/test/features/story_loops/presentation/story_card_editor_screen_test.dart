import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/story_loops/application/story_card_editor_controller.dart';
import 'package:vinscent/features/story_loops/data/story_card_draft.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/presentation/story_card_editor_screen.dart';

void main() {
  testWidgets('keeps the editor header at the top of the screen', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    final header = find.byKey(const ValueKey('story-card-editor-header'));
    final save = find.byKey(const ValueKey('story-card-editor-save'));
    final textTool = find.byIcon(Icons.text_fields);

    expect(tester.getSize(header).height, 56);
    expect(tester.getTopLeft(header).dy, 0);
    expect(tester.getRect(save).overlaps(tester.getRect(textTool)), isFalse);
  });

  testWidgets('delivers text placement taps to the canvas', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    await _openTextDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('keeps the text controller alive through dialog dismissal', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    await _openTextDialog(tester);
    await tester.enterText(find.byType(TextField), 'first text');
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('first text'), findsOneWidget);

    await tester.tap(find.text('first text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'updated text');
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('updated text'), findsOneWidget);

    await tester.tap(find.text('updated text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('updated text'), findsNothing);
  });

  testWidgets('keeps the text controller alive when input is cancelled', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    await _openTextDialog(tester);
    await tester.enterText(find.byType(TextField), 'cancelled text');
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('cancelled text'), findsNothing);
  });

  testWidgets('delivers drawing pointer events to the canvas', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    TextButton saveButton() => tester.widget<TextButton>(
      find.byKey(const ValueKey('story-card-editor-save')),
    );

    expect(saveButton().onPressed, isNull);

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    await tester.dragFrom(center - const Offset(30, 30), const Offset(60, 60));
    await tester.pump();

    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('drawing mode exposes eraser undo and done without crop', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    expect(find.byKey(const ValueKey('story-card-drawing-eraser')), findsOne);
    expect(find.byKey(const ValueKey('story-card-drawing-undo')), findsOne);
    expect(find.byKey(const ValueKey('story-card-drawing-done')), findsOne);
    expect(find.byIcon(Icons.crop), findsNothing);
  });

  testWidgets('undo removes the last completed drawing stroke', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    TextButton saveButton() => tester.widget<TextButton>(
      find.byKey(const ValueKey('story-card-editor-save')),
    );

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    await tester.dragFrom(center - const Offset(30, 0), const Offset(60, 0));
    await tester.pump();

    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('story-card-drawing-undo')));
    await tester.pump();

    expect(saveButton().onPressed, isNull);
  });

  testWidgets('drawing done returns a photo card to background gestures', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-card-drawing-done')));
    await tester.pump();

    expect(find.byKey(const ValueKey('story-card-drawing-done')), findsNothing);
    expect(find.byIcon(Icons.crop), findsNothing);

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    final first = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveBy(const Offset(20, 30));
    await second.moveBy(const Offset(20, 30));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final transform = _backgroundTransform(tester);
    expect(transform.offsetX, isNot(0));
    expect(transform.offsetY, isNot(0));
  });

  testWidgets('moves text with one finger', (tester) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    final text = find.text('pinch target');
    final before = tester.getCenter(text);
    await tester.dragFrom(before, const Offset(30, 40));
    await tester.pump();

    final after = tester.getCenter(text);
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
  });

  testWidgets('scales text when only one pointer starts on the text', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final text = find.text('pinch target');
    final textCenter = tester.getCenter(text);
    final secondStart = textCenter + const Offset(0, 100);
    expect(tester.getRect(canvas).contains(secondStart), isTrue);
    expect(tester.getRect(text).contains(secondStart), isFalse);

    final beforeScale = _textScale(tester, 'pinch target');
    final first = await tester.startGesture(textCenter, pointer: 1);
    final second = await tester.startGesture(secondStart, pointer: 2);
    await tester.pump();
    await second.moveTo(secondStart + const Offset(0, 100));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(_textScale(tester, 'pinch target'), greaterThan(beforeScale));
  });

  testWidgets('rotates text when only one pointer starts on the text', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    final textCenter = tester.getCenter(find.text('pinch target'));
    final outsideStart = textCenter + const Offset(100, 0);
    final first = await tester.startGesture(textCenter, pointer: 1);
    final second = await tester.startGesture(outsideStart, pointer: 2);
    await tester.pump();
    await second.moveTo(textCenter + const Offset(0, 100));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(_textRotation(tester, 'text-1').abs(), greaterThan(0.5));
  });

  testWidgets('renders text without a shadow', (tester) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    final text = tester.widget<Text>(find.text('pinch target'));

    expect(text.style?.shadows, isEmpty);
  });

  testWidgets('scales text when the outside pointer starts first', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    final textCenter = tester.getCenter(find.text('pinch target'));
    final outsideStart = textCenter + const Offset(0, 100);
    final beforeScale = _textScale(tester, 'pinch target');
    final first = await tester.startGesture(outsideStart, pointer: 1);
    final second = await tester.startGesture(textCenter, pointer: 2);
    await tester.pump();
    await first.moveTo(outsideStart + const Offset(0, 100));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(_textScale(tester, 'pinch target'), greaterThan(beforeScale));
  });

  testWidgets('prioritizes text over the background during a pinch', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoTextDraft());

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final textCenter = tester.getCenter(find.text('pinch target'));
    final secondStart = textCenter + const Offset(0, 100);
    expect(tester.getRect(canvas).contains(secondStart), isTrue);

    final beforeScale = _textScale(tester, 'pinch target');
    final first = await tester.startGesture(textCenter, pointer: 1);
    final second = await tester.startGesture(secondStart, pointer: 2);
    await tester.pump();
    await second.moveTo(secondStart + const Offset(0, 100));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final backgroundTransform = _backgroundTransform(tester);
    expect(_textScale(tester, 'pinch target'), greaterThan(beforeScale));
    expect(backgroundTransform.scale, 1);
    expect(backgroundTransform.offsetX, 0);
    expect(backgroundTransform.offsetY, 0);
  });

  testWidgets('delivers background transform gestures to the canvas', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final scaleDetectors = tester
        .widgetList<GestureDetector>(
          find.descendant(of: canvas, matching: find.byType(GestureDetector)),
        )
        .where((detector) => detector.onScaleUpdate != null);
    expect(scaleDetectors, hasLength(1));

    final center = tester.getCenter(canvas);
    final first = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveBy(const Offset(30, 40));
    await second.moveBy(const Offset(30, 40));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final transform = _backgroundTransform(tester);
    expect(transform.offsetX, isNot(0));
    expect(transform.offsetY, isNot(0));
  });

  testWidgets('moves the background only with two pointers', (tester) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    await tester.dragFrom(center, const Offset(30, 40));
    await tester.pump();

    var transform = _backgroundTransform(tester);
    expect(transform.offsetX, 0);
    expect(transform.offsetY, 0);

    final first = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 1,
    );
    final second = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 2,
    );
    await tester.pump();
    await first.moveBy(const Offset(30, 40));
    await second.moveBy(const Offset(30, 40));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    transform = _backgroundTransform(tester);
    expect(transform.offsetX, isNot(0));
    expect(transform.offsetY, isNot(0));

    final scaleBeforePinch = transform.scale;
    final pinchFirst = await tester.startGesture(
      center - const Offset(30, 0),
      pointer: 3,
    );
    final pinchSecond = await tester.startGesture(
      center + const Offset(30, 0),
      pointer: 4,
    );
    await tester.pump();
    await pinchSecond.moveBy(const Offset(60, 0));
    await tester.pump();
    await pinchFirst.up();
    await pinchSecond.up();
    await tester.pump();

    expect(_backgroundTransform(tester).scale, greaterThan(scaleBeforePinch));
  });

  testWidgets('moves the background with two pointers while text tool is on', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoTextDraft());

    await tester.tap(find.byIcon(Icons.text_fields));
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final canvasRect = tester.getRect(canvas);
    final firstStart = Offset(
      canvasRect.left + 30,
      canvasRect.top + canvasRect.height * 0.75,
    );
    final secondStart = firstStart + const Offset(60, 0);
    final first = await tester.startGesture(firstStart, pointer: 1);
    final second = await tester.startGesture(secondStart, pointer: 2);
    await tester.pump();
    await first.moveBy(const Offset(20, 30));
    await second.moveBy(const Offset(20, 30));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final transform = _backgroundTransform(tester);
    expect(transform.offsetX, isNot(0));
    expect(transform.offsetY, isNot(0));
    expect(find.byType(AlertDialog), findsNothing);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required StoryCardDraft draft,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyCardEditorControllerProvider.overrideWith(
          () => _TestStoryCardEditorController(draft),
        ),
      ],
      child: const MaterialApp(home: StoryCardEditorScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openTextDialog(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.text_fields));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('story-card-editor-canvas')));
  await tester.pumpAndSettle();
}

StoryCardDraft _existingEmptyDraft() {
  return StoryCardDraft(scene: StoryCardScene.empty(), existingRevision: 1);
}

StoryCardDraft _existingPhotoDraft() {
  final photo = image.Image(width: 4, height: 4);
  return StoryCardDraft(
    scene: StoryCardScene.empty(),
    backgroundImageBytes: Uint8List.fromList(image.encodePng(photo)),
    existingRevision: 1,
  );
}

StoryCardDraft _existingTextDraft() {
  return const StoryCardDraft(
    scene: StoryCardScene(
      backgroundTransform: StoryCardBackgroundTransform.initial(),
      strokes: [],
      textLayers: [
        StoryCardTextLayer(
          id: 'text-1',
          text: 'pinch target',
          x: 0.5,
          y: 0.5,
          color: Colors.black,
          scale: 0.5,
        ),
      ],
    ),
    existingRevision: 1,
  );
}

StoryCardDraft _existingPhotoTextDraft() {
  final photo = image.Image(width: 4, height: 4);
  return StoryCardDraft(
    scene: _existingTextDraft().scene,
    backgroundImageBytes: Uint8List.fromList(image.encodePng(photo)),
    existingRevision: 1,
  );
}

double _textScale(WidgetTester tester, String value) {
  final transform = tester.widget<Transform>(
    find.ancestor(of: find.text(value), matching: find.byType(Transform)),
  );
  return transform.transform.entry(0, 0).abs();
}

double _textRotation(WidgetTester tester, String layerId) {
  final transform = tester.widget<Transform>(
    find.byKey(ValueKey('story-card-text-transform-$layerId')),
  );
  final matrix = transform.transform;
  return math.atan2(matrix.entry(1, 0), matrix.entry(0, 0));
}

StoryCardBackgroundTransform _backgroundTransform(WidgetTester tester) {
  final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: canvas, matching: find.byType(CustomPaint)).first,
  );
  final dynamic painter = customPaint.painter;
  return painter.backgroundTransform as StoryCardBackgroundTransform;
}

class _TestStoryCardEditorController extends StoryCardEditorController {
  _TestStoryCardEditorController(this.draft);

  final StoryCardDraft draft;

  @override
  Future<StoryCardDraft> build() async => draft;
}
