import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/core/presentation/widgets/app_svg_icon.dart';
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

  testWidgets('uses a 4:5 polaroid frame in the editor', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final size = tester.getSize(canvas);

    expect(size.width / size.height, closeTo(4 / 5, 0.001));
  });

  testWidgets(
    'edits an optional fixed caption with 50 characters and 2 lines',
    (tester) async {
      await _pumpEditor(tester, draft: _existingEmptyDraft());

      await _openCaptionInput(tester);

      expect(
        find.byKey(const ValueKey('story-card-caption-input-overlay')),
        findsOneWidget,
      );
      final inputFinder = find.byKey(
        const ValueKey('story-card-caption-input'),
      );
      final input = tester.widget<TextField>(inputFinder);
      expect(input.maxLength, storyCardMaxCaptionCharacters);
      expect(input.maxLines, storyCardMaxCaptionLines);
      expect(input.textAlign, TextAlign.center);

      await tester.enterText(inputFinder, 'first date');
      await tester.tap(
        find.byKey(const ValueKey('story-card-caption-input-done')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('story-card-caption-input-overlay')),
        findsNothing,
      );
      expect(_captionFromPainter(tester), 'first date');
    },
  );

  testWidgets('centers the fixed caption in the bottom area', (tester) async {
    await _pumpEditor(tester, draft: _existingCaptionDraft());

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(of: canvas, matching: find.byType(RepaintBoundary)),
    );
    ui.Image? rendered;
    ByteData? bytes;
    await tester.runAsync(() async {
      rendered = await boundary.toImage(pixelRatio: 1);
      bytes = await rendered!.toByteData(format: ui.ImageByteFormat.rawRgba);
    });

    final capturedImage = rendered!;
    final capturedBytes = bytes!;
    addTearDown(capturedImage.dispose);
    final captionBounds = _darkPixelBounds(
      capturedBytes,
      capturedImage,
      minimumY: 0.75,
    );

    expect(captionBounds, isNotNull);
    expect(captionBounds!.center.dx / capturedImage.width, closeTo(0.5, 0.03));
  });

  testWidgets('limits the fixed caption to 50 grapheme characters', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());
    await _openCaptionInput(tester);

    final inputFinder = find.byKey(const ValueKey('story-card-caption-input'));
    await tester.enterText(inputFinder, 'a' * 51);
    await tester.pump();

    final input = tester.widget<TextField>(inputFinder);
    expect(input.controller?.text, 'a' * 50);
  });

  testWidgets('keeps only the first two caption lines when text is pasted', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());
    await _openCaptionInput(tester);

    final inputFinder = find.byKey(const ValueKey('story-card-caption-input'));
    await tester.enterText(inputFinder, 'first\nsecond\nthird');
    await tester.pump();

    final input = tester.widget<TextField>(inputFinder);
    expect(input.controller?.text, 'first\nsecond');
  });

  testWidgets('does not enable save for a caption-only card', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());
    await _openCaptionInput(tester);
    await tester.enterText(
      find.byKey(const ValueKey('story-card-caption-input')),
      'caption only',
    );
    await tester.tap(
      find.byKey(const ValueKey('story-card-caption-input-done')),
    );
    await tester.pumpAndSettle();

    final save = tester.widget<TextButton>(
      find.byKey(const ValueKey('story-card-editor-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('clips a photo to the square polaroid photo area', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingRedPhotoDraft());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(of: canvas, matching: find.byType(RepaintBoundary)),
    );
    ui.Image? rendered;
    ByteData? bytes;
    await tester.runAsync(() async {
      rendered = await boundary.toImage(pixelRatio: 1);
      bytes = await rendered!.toByteData(format: ui.ImageByteFormat.rawRgba);
    });

    final capturedImage = rendered!;
    final capturedBytes = bytes!;
    addTearDown(capturedImage.dispose);
    expect(
      _pixelAt(capturedBytes, capturedImage, x: 0.5, y: 0.5),
      const Color(0xFFFF0000),
    );
    expect(
      _pixelAt(capturedBytes, capturedImage, x: 0.5, y: 0.9),
      const Color(0xFFFFFFFF),
    );
  });

  testWidgets('opens inline text input with focus instead of a dialog', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    await _openTextInput(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('story-card-text-input-overlay')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    final input = tester.widget<TextField>(find.byType(TextField));
    expect(input.autofocus, isTrue);
    expect(input.style?.color, Colors.white);
    expect(input.cursorColor, Colors.white);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('creates centered text with the selected input color', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());
    const selectedColor = Color(0xFFE94B5F);

    await _openTextInput(tester);
    await tester.enterText(find.byType(TextField), 'new text');
    await tester.tap(
      find.byKey(const ValueKey('story-card-text-input-color-2')),
    );
    await tester.pump();

    var input = tester.widget<TextField>(find.byType(TextField));
    expect(input.style?.color, selectedColor);
    expect(input.cursorColor, selectedColor);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('story-card-text-input-overlay')),
      findsNothing,
    );
    final createdText = find.text('new text');
    expect(createdText, findsOneWidget);
    expect(tester.widget<Text>(createdText).style?.color, selectedColor);
    expect(
      (tester.getCenter(createdText) -
              tester.getCenter(
                find.byKey(const ValueKey('story-card-editor-canvas')),
              ))
          .distance,
      lessThan(1),
    );
  });

  testWidgets('cancels inline text input without changing the draft', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    await _openTextInput(tester);
    await tester.enterText(find.byType(TextField), 'cancelled text');
    await tester.tap(
      find.byKey(const ValueKey('story-card-text-input-cancel')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('story-card-text-input-overlay')),
      findsNothing,
    );
    expect(find.text('cancelled text'), findsNothing);
    final save = tester.widget<TextButton>(
      find.byKey(const ValueKey('story-card-editor-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('back cancels inline text input before leaving the editor', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());
    await _openTextInput(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('story-card-text-input-overlay')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('story-card-editor-canvas')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('does not edit an existing text layer on tap', (tester) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    await tester.tap(find.text('pinch target'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.byKey(const ValueKey('story-card-text-input-overlay')),
      findsNothing,
    );
    expect(find.text('pinch target'), findsOneWidget);
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

    final eraserIcon = find.descendant(
      of: find.byKey(const ValueKey('story-card-drawing-eraser')),
      matching: find.byType(AppSvgIcon),
    );
    expect(eraserIcon, findsOneWidget);
    expect(
      tester.widget<AppSvgIcon>(eraserIcon).assetName,
      'assets/icons/eraser_black.svg',
    );
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

  testWidgets('eraser clears drawing pixels without clearing the background', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingErasedDrawingDraft());

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(of: canvas, matching: find.byType(RepaintBoundary)),
    );
    ui.Image? rendered;
    ByteData? bytes;
    await tester.runAsync(() async {
      rendered = await boundary.toImage(pixelRatio: 1);
      bytes = await rendered!.toByteData(format: ui.ImageByteFormat.rawRgba);
    });

    expect(rendered, isNotNull);
    expect(bytes, isNotNull);
    final capturedImage = rendered!;
    final capturedBytes = bytes!;
    addTearDown(capturedImage.dispose);
    final visiblePen = _pixelAt(capturedBytes, capturedImage, x: 0.3, y: 0.5);
    final erasedIntersection = _pixelAt(
      capturedBytes,
      capturedImage,
      x: 0.5,
      y: 0.5,
    );

    expect(visiblePen, const Color(0xFFFFFFFF));
    expect(erasedIntersection, const Color(0xFF000000));
  });

  testWidgets('drawing done returns a photo card to background gestures', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-card-drawing-done')));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
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

  testWidgets('deletes text when it is dropped on the trash target', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    final text = find.text('pinch target');
    final gesture = await tester.startGesture(tester.getCenter(text));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    final trash = find.byKey(const ValueKey('story-card-text-trash-target'));
    final trashIcon = find.byKey(const ValueKey('story-card-text-trash-icon'));
    expect(trash, findsOneWidget);
    final inactiveColor = tester.widget<Icon>(trashIcon).color;

    await gesture.moveTo(tester.getCenter(trash));
    await tester.pump();

    expect(tester.widget<Icon>(trashIcon).color, isNot(inactiveColor));

    await gesture.up();
    await tester.pump();

    expect(find.text('pinch target'), findsNothing);
    expect(trash, findsNothing);
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

    final beforeScale = _textScale(tester, 'text-1');
    final first = await tester.startGesture(textCenter, pointer: 1);
    final second = await tester.startGesture(secondStart, pointer: 2);
    await tester.pump();
    await second.moveTo(secondStart + const Offset(0, 100));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(_textScale(tester, 'text-1'), greaterThan(beforeScale));
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

  testWidgets('continues moving text with the remaining outside pointer', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingTextDraft());

    final textCenter = tester.getCenter(find.text('pinch target'));
    final outsideStart = textCenter + const Offset(0, 100);
    final textPointer = await tester.startGesture(textCenter, pointer: 1);
    final outsidePointer = await tester.startGesture(outsideStart, pointer: 2);
    await outsidePointer.moveBy(const Offset(0, 30));
    await tester.pump();
    await textPointer.up();
    await tester.pump();

    final before = tester.getCenter(find.text('pinch target'));
    await outsidePointer.moveBy(const Offset(40, 30));
    await tester.pump();
    await outsidePointer.moveBy(const Offset(20, 15));
    await tester.pump();
    final after = tester.getCenter(find.text('pinch target'));

    await outsidePointer.up();
    await tester.pump();

    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
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
    final beforeScale = _textScale(tester, 'text-1');
    final first = await tester.startGesture(outsideStart, pointer: 1);
    final second = await tester.startGesture(textCenter, pointer: 2);
    await tester.pump();
    await first.moveTo(outsideStart + const Offset(0, 100));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(_textScale(tester, 'text-1'), greaterThan(beforeScale));
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

    final beforeScale = _textScale(tester, 'text-1');
    final first = await tester.startGesture(textCenter, pointer: 1);
    final second = await tester.startGesture(secondStart, pointer: 2);
    await tester.pump();
    await second.moveTo(secondStart + const Offset(0, 100));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final backgroundTransform = _backgroundTransform(tester);
    expect(_textScale(tester, 'text-1'), greaterThan(beforeScale));
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

  testWidgets('returns to background gestures after text input is cancelled', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoTextDraft());

    await _openTextInput(tester);
    await tester.tap(
      find.byKey(const ValueKey('story-card-text-input-cancel')),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
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
    expect(
      find.byKey(const ValueKey('story-card-text-input-overlay')),
      findsNothing,
    );
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

Future<void> _openTextInput(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.text_fields));
  await tester.pumpAndSettle();
}

Future<void> _openCaptionInput(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('story-card-caption-tool')));
  await tester.pumpAndSettle();
}

StoryCardDraft _existingEmptyDraft() {
  return StoryCardDraft(scene: StoryCardScene.empty(), existingRevision: 1);
}

StoryCardDraft _existingCaptionDraft() {
  return StoryCardDraft(
    scene: StoryCardScene.empty().copyWith(caption: 'center'),
    existingRevision: 1,
  );
}

StoryCardDraft _existingPhotoDraft() {
  final photo = image.Image(width: 4, height: 4);
  return StoryCardDraft(
    scene: StoryCardScene.empty(),
    backgroundImageBytes: Uint8List.fromList(image.encodePng(photo)),
    existingRevision: 1,
  );
}

StoryCardDraft _existingRedPhotoDraft() {
  final photo = image.Image(width: 4, height: 4);
  image.fill(photo, color: image.ColorRgb8(255, 0, 0));
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

StoryCardDraft _existingErasedDrawingDraft() {
  return const StoryCardDraft(
    scene: StoryCardScene(
      canvasBackground: StoryCardCanvasBackground.black,
      backgroundTransform: StoryCardBackgroundTransform.initial(),
      strokes: [
        StoryCardStroke(
          tool: StoryCardDrawingTool.pen,
          color: Colors.white,
          width: storyCardMaxStrokeWidth,
          points: [
            StoryCardPoint(x: 0.2, y: 0.5),
            StoryCardPoint(x: 0.8, y: 0.5),
          ],
        ),
        StoryCardStroke(
          tool: StoryCardDrawingTool.eraser,
          color: Colors.black,
          width: storyCardMaxStrokeWidth,
          points: [
            StoryCardPoint(x: 0.5, y: 0.4),
            StoryCardPoint(x: 0.5, y: 0.6),
          ],
        ),
      ],
      textLayers: [],
    ),
    existingRevision: 1,
  );
}

double _textScale(WidgetTester tester, String layerId) {
  final transform = tester.widget<Transform>(
    find.byKey(ValueKey('story-card-text-scale-$layerId')),
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

String? _captionFromPainter(WidgetTester tester) {
  final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: canvas, matching: find.byType(CustomPaint)).first,
  );
  final dynamic painter = customPaint.painter;
  return painter.caption as String?;
}

Color _pixelAt(
  ByteData bytes,
  ui.Image image, {
  required double x,
  required double y,
}) {
  final pixelX = (image.width * x).floor().clamp(0, image.width - 1);
  final pixelY = (image.height * y).floor().clamp(0, image.height - 1);
  final offset = (pixelY * image.width + pixelX) * 4;
  return Color.fromARGB(
    bytes.getUint8(offset + 3),
    bytes.getUint8(offset),
    bytes.getUint8(offset + 1),
    bytes.getUint8(offset + 2),
  );
}

Rect? _darkPixelBounds(
  ByteData bytes,
  ui.Image image, {
  required double minimumY,
}) {
  int? left;
  int? top;
  int? right;
  int? bottom;
  final startY = (image.height * minimumY).floor().clamp(0, image.height - 1);

  for (var y = startY; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final offset = (y * image.width + x) * 4;
      final red = bytes.getUint8(offset);
      final green = bytes.getUint8(offset + 1);
      final blue = bytes.getUint8(offset + 2);
      final alpha = bytes.getUint8(offset + 3);
      if (alpha == 0 || red >= 128 || green >= 128 || blue >= 128) {
        continue;
      }

      left = left == null || x < left ? x : left;
      top = top == null || y < top ? y : top;
      right = right == null || x > right ? x : right;
      bottom = bottom == null || y > bottom ? y : bottom;
    }
  }

  if (left == null || top == null || right == null || bottom == null) {
    return null;
  }
  return Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    (right + 1).toDouble(),
    (bottom + 1).toDouble(),
  );
}

class _TestStoryCardEditorController extends StoryCardEditorController {
  _TestStoryCardEditorController(this.draft);

  final StoryCardDraft draft;

  @override
  Future<StoryCardDraft> build() async => draft;
}
