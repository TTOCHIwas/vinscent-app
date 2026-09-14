import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/core/drawing/widgets/app_color_sampler.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_style_controls.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_toolbar.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_width_slider.dart';
import 'package:vinscent/core/presentation/widgets/app_svg_icon.dart';
import 'package:vinscent/features/story_loops/application/story_card_editor_controller.dart';
import 'package:vinscent/features/story_loops/data/story_card_appearance.dart';
import 'package:vinscent/features/story_loops/data/story_card_draft.dart';
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';
import 'package:vinscent/features/story_loops/presentation/story_card_editor_screen.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_drawing_controls.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_interactive_viewport.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_photo_adjustment_screen.dart';
import '../../../support/color_picker_test_helpers.dart';

void main() {
  for (final confirm in [false, true]) {
    testWidgets('discard dialog preserves saved card with confirm=$confirm', (
      tester,
    ) async {
      await _pumpEditor(tester, draft: _existingCaptionDraft());
      await tester.tap(find.byKey(const ValueKey('story-card-type-tool')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(
        find.byKey(const ValueKey('story-card-editor-background-color-2')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('수정 내용을 버릴까요?'), findsOneWidget);
      expect(find.text('저장하지 않은 변경 내용이 사라져요.'), findsOneWidget);
      expect(find.text('버리기'), findsOneWidget);
      expect(find.text('수정 버리기'), findsNothing);
      await tester.tap(
        find.byKey(Key('app-confirmation-${confirm ? 'confirm' : 'cancel'}')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(StoryCardEditorScreen), findsOneWidget);
      expect(_captionFromPainter(tester), 'center');
    });
  }

  for (final screen in [
    const Size(360, 800),
    const Size(900, 1200),
    const Size(800, 360),
  ]) {
    testWidgets('drawing controls overlay the unchanged card on $screen', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(screen);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpEditor(tester, draft: _existingEmptyDraft());
      final initialCanvas = tester.getRect(
        find.byKey(const ValueKey('story-card-editor-canvas')),
      );
      await tester.tap(find.byIcon(Icons.brush_outlined));
      await tester.pump();
      final canvas = tester.getSize(
        find.byKey(const ValueKey('story-card-editor-canvas')),
      );
      final drawingCanvas = tester.getRect(
        find.byKey(const ValueKey('story-card-editor-canvas')),
      );
      final slider = tester.widget<AppDrawingWidthSlider>(
        find.byType(AppDrawingWidthSlider),
      );
      expect(
        tester
            .widget<StoryCardInteractiveViewport>(
              find.byType(StoryCardInteractiveViewport),
            )
            .clipContent,
        isFalse,
      );
      expect(slider.canvasExtent, closeTo(canvas.shortestSide, 0.001));
      expect(canvas.width / canvas.height, closeTo(4 / 5, 0.001));
      final widthControl = tester.getRect(
        find.byKey(const ValueKey('story-card-drawing-width-control')),
      );
      final tools = tester.getRect(
        find.byKey(const ValueKey('story-card-drawing-toolbar')),
      );
      final palette = tester.getRect(
        find.byKey(const ValueKey('story-card-drawing-color-palette')),
      );
      expect(widthControl.height, 48);
      expect(widthControl.width, greaterThan(screen.width * 0.8));
      expect(tools.bottom, widthControl.top);
      expect(tools.width, screen.width);
      expect(widthControl.bottom, palette.top);
      expect(widthControl.center.dx, palette.center.dx);
      final drawingBounds = tester.getRect(
        find.byType(StoryCardDrawingControls),
      );
      final done = tester.getRect(
        find.byKey(const ValueKey('story-card-drawing-done')),
      );
      expect(done.top, drawingBounds.top + 4);
      expect(done.right, drawingBounds.right - 12);
      for (final tool in ['pen', 'eraser', 'undo']) {
        final button = tester.getRect(
          find.byKey(ValueKey('story-card-drawing-$tool')),
        );
        expect(button.center.dy, tools.center.dy);
      }
      expect(drawingCanvas, initialCanvas);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await gesture.moveBy(const Offset(120, 0));
      await tester.pumpAndSettle();
      final preview = tester.getRect(
        find.byKey(const ValueKey('drawing-width-preview')),
      );
      expect(preview.bottom, lessThanOrEqualTo(tools.top - 8));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('story-card-editor-canvas'))),
        drawingCanvas,
      );
      final controls = tester.widget<StoryCardDrawingControls>(
        find.byType(StoryCardDrawingControls),
      );
      expect(controls.canUndo, isFalse);
      await tester.tap(find.byKey(const ValueKey('story-card-drawing-done')));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const ValueKey('story-card-editor-canvas'))),
        initialCanvas,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('세로 네컷의 그리기 팔레트는 카드 크기를 줄이지 않는 오버레이로 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpEditor(
      tester,
      draft: _photoDraftForType(StoryCardType.fourCutStrip),
    );
    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final initialCanvas = tester.getRect(canvas);

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    final drawingCanvas = tester.getRect(canvas);
    expect(drawingCanvas, initialCanvas);
    expect(
      find.byKey(const ValueKey('story-card-drawing-color-palette')),
      findsOneWidget,
    );
  });

  testWidgets('확대한 카드에서 한 손가락 그림은 화면을 이동시키지 않는다', (tester) async {
    await _pumpEditor(tester, draft: _existingRedPhotoDraft());
    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    final first = await tester.startGesture(center - const Offset(30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));
    await first.moveTo(center - const Offset(70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final viewport = tester.widget<StoryCardInteractiveViewport>(
      find.byType(StoryCardInteractiveViewport),
    );
    expect(viewport.controller.scale, greaterThan(1.5));

    final translationBeforePan = viewport.controller.translation;
    await tester.drag(canvas, const Offset(0, 48));
    await tester.pump();
    expect(
      viewport.controller.translation.dy,
      greaterThan(translationBeforePan.dy),
    );

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();
    final translationBeforeDrawing = viewport.controller.translation;
    await tester.drag(canvas, const Offset(28, 0));
    await tester.pump();

    expect(viewport.controller.translation, translationBeforeDrawing);
    expect(
      tester
          .widget<StoryCardDrawingControls>(
            find.byType(StoryCardDrawingControls),
          )
          .canUndo,
      isTrue,
    );
  });

  for (final cancel in [false, true]) {
    testWidgets(
      'text eyedropper preserves draft and selection on ${cancel ? 'cancel' : 'selection'}',
      (tester) async {
        await _pumpEditor(tester, draft: _existingRedPhotoDraft());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await tester.tap(find.byIcon(Icons.text_fields));
        await tester.pumpAndSettle();
        final inputFinder = find.byKey(const ValueKey('story-card-text-input'));
        await tester.enterText(inputFinder, '함께 남긴 하루');
        final input = tester.widget<TextField>(inputFinder);
        const selection = TextSelection.collapsed(offset: 3);
        input.controller!.selection = selection;
        await tester.pump();
        final picker = await openColorPicker(
          tester,
          buttonPrefix: 'story-card-text-input',
        );
        expect(inputFinder, findsNothing);
        expect(tester.testTextInput.isVisible, isFalse);
        if (cancel) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tapAt(picker.canvasRect.center);
        }
        await tester.pumpAndSettle();
        final restored = tester.widget<TextField>(inputFinder);
        expect(restored.controller!.text, '함께 남긴 하루');
        expect(restored.controller!.selection, selection);
        expect(restored.focusNode!.hasFocus, isTrue);
        expect(
          restored.style!.color,
          cancel ? Colors.white : const Color(0xFFFF0000),
        );
      },
    );
  }

  testWidgets('keeps the editor header at the top of the screen', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    final header = find.byKey(const ValueKey('story-card-editor-header'));
    final save = find.byKey(const ValueKey('story-card-editor-save'));
    final textTool = find.byIcon(Icons.text_fields);

    expect(tester.getSize(header).height, 56);
    expect(tester.getTopLeft(header).dy, 0);
    expect(
      tester.widget(
        find.byKey(const ValueKey('story-card-editor-header-surface')),
      ),
      isNot(isA<ColoredBox>()),
    );
    expect(tester.getRect(save).overlaps(tester.getRect(textTool)), isFalse);
    final saveIcon = tester.widget<Icon>(
      find.descendant(of: save, matching: find.byIcon(Icons.check_rounded)),
    );
    expect(saveIcon.shadows, isNotEmpty);
    final backIcon = tester.widget<Icon>(
      find.descendant(
        of: header,
        matching: find.byIcon(Icons.chevron_left_rounded),
      ),
    );
    expect(backIcon.shadows, isNotEmpty);
    expect(find.byTooltip('카드 올리기'), findsOneWidget);
    expect(find.byTooltip('카드 삭제'), findsNothing);
    expect(find.text('올리기'), findsNothing);
    expect(find.text('오늘의 스토리'), findsNothing);
  });

  testWidgets('uses a 4:5 polaroid frame in the editor', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final size = tester.getSize(canvas);

    expect(size.width / size.height, closeTo(4 / 5, 0.001));
  });

  testWidgets('세로 네컷 카드는 헤더와 하단 선택 영역 사이에 여백을 둔다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpEditor(
      tester,
      draft: _photoDraftForType(
        StoryCardType.fourCutStrip,
        existingRevision: 1,
      ),
    );

    final header = tester.getRect(
      find.byKey(const ValueKey('story-card-editor-header')),
    );
    final canvas = tester.getRect(
      find.byKey(const ValueKey('story-card-editor-canvas')),
    );

    expect(canvas.top, greaterThanOrEqualTo(header.bottom + 12));
    expect(canvas.bottom, lessThanOrEqualTo(800 - 72));
    expect(canvas.width / canvas.height, closeTo(2 / 5, 0.001));
  });

  testWidgets('최초 카드 편집 안내를 닫아도 유형 선택기는 다음 조작까지 유지된다', (tester) async {
    await _pumpEditor(
      tester,
      draft: _photoDraftForType(StoryCardType.fullBleed),
    );

    final guide = find.byKey(const ValueKey('story-card-editor-type-guide'));
    final selectorSlide = find.byKey(
      const ValueKey('story-card-editor-type-selector-slide'),
    );
    expect(guide, findsOneWidget);
    expect(selectorSlide, findsOneWidget);
    expect(tester.widget<AnimatedSlide>(selectorSlide).offset, Offset.zero);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('story-card-editor-canvas'))),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(guide, findsNothing);
    expect(tester.widget<AnimatedSlide>(selectorSlide).offset, Offset.zero);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('story-card-editor-canvas'))),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      tester.widget<AnimatedSlide>(selectorSlide).offset.dy,
      greaterThan(0),
    );
    expect(find.byType(StoryCardPhotoAdjustmentScreen), findsNothing);
  });

  testWidgets('하단 유형 선택기가 보여도 캔버스 좌우 스와이프로 유형을 바꾼다', (tester) async {
    await _pumpEditor(
      tester,
      draft: _photoDraftForType(StoryCardType.fullBleed),
    );

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final selectorSlide = find.byKey(
      const ValueKey('story-card-editor-type-selector-slide'),
    );

    await tester.tapAt(tester.getCenter(canvas));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<AnimatedSlide>(selectorSlide).offset, Offset.zero);

    for (var index = 0; index < 3; index++) {
      await tester.drag(canvas, const Offset(-100, 0));
      await tester.pump();
    }

    expect(tester.getSize(canvas).aspectRatio, closeTo(2 / 5, 0.001));
    expect(tester.widget<AnimatedSlide>(selectorSlide).offset, Offset.zero);
  });

  testWidgets('카드 유형 아이콘 선택은 캔버스를 바꾸고 2초 뒤 선택기를 내린다', (tester) async {
    await _pumpEditor(
      tester,
      draft: _photoDraftForType(StoryCardType.fullBleed),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(
      find.byKey(const ValueKey('story-card-editor-type-four-cut-strip')),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final selectorSlide = find.byKey(
      const ValueKey('story-card-editor-type-selector-slide'),
    );
    expect(tester.getSize(canvas).aspectRatio, closeTo(2 / 5, 0.001));
    expect(tester.widget<AnimatedSlide>(selectorSlide).offset, Offset.zero);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.widget<AnimatedSlide>(selectorSlide).offset.dy,
      greaterThan(0),
    );

    await tester.tap(find.byKey(const ValueKey('story-card-type-tool')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<AnimatedSlide>(selectorSlide).offset, Offset.zero);
  });

  testWidgets('카드 유형 패널에서 배경색을 바꾸고 직접 선택기를 연다', (tester) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.tap(find.byKey(const ValueKey('story-card-type-tool')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('배경'), findsOneWidget);
    expect(find.byIcon(Icons.contrast), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('story-card-editor-background-color-2')),
    );
    await tester.pump();
    expect(
      _appearanceFromPainter(tester).backgroundColor,
      storyCardBackgroundColorPalette[2],
    );

    await tester.tap(
      find.byKey(const ValueKey('story-card-editor-background-custom')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('app-hsv-color-picker-sheet')),
      findsOneWidget,
    );
  });

  testWidgets('프레임 없는 사진도 전체 카드 비율 사진 조정 화면을 연다', (tester) async {
    await _pumpEditor(
      tester,
      draft: _photoDraftForType(StoryCardType.fullBleed, existingRevision: 1),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('story-card-editor-canvas'))),
    );
    await _pumpPhotoAdjustmentRoute(tester);

    final cropFrame = find.byKey(
      const ValueKey('story-card-photo-adjustment-crop-frame'),
    );
    expect(find.byType(StoryCardPhotoAdjustmentScreen), findsOneWidget);
    expect(tester.getSize(cropFrame).aspectRatio, closeTo(4 / 5, 0.01));
  });

  testWidgets('기존 폴라로이드 문구는 보존하지만 신규 입력 도구는 제공하지 않는다', (tester) async {
    await _pumpEditor(tester, draft: _existingCaptionDraft());

    expect(_captionFromPainter(tester), 'center');
    expect(find.byKey(const ValueKey('story-card-caption-tool')), findsNothing);
    expect(
      find.byKey(const ValueKey('story-card-caption-input-overlay')),
      findsNothing,
    );
  });

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

  testWidgets('does not enable save for a caption-only card', (tester) async {
    await _pumpEditor(tester, draft: _existingCaptionDraft());

    final save = tester.widget<IconButton>(
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

  testWidgets('photo decorator exposes and applies the shared film selector', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingRedPhotoDraft());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('story-card-film-tool')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('story-card-editor-film-selector')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('story-card-editor-film-moment')),
    );
    await tester.pump();

    expect(_filmFromPainter(tester).look, StoryCardFilmLook.moment);
    expect(_filmFromPainter(tester).seed, greaterThan(0));
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('story-card-text-input-done')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('텍스트 입력 완료'), findsOneWidget);
  });

  testWidgets('creates centered text with the selected input color', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());
    const selectedColor = Color(0xFFE94B5F);
    final selectedColorIndex = storyCardColorPalette.indexOf(selectedColor);

    await _openTextInput(tester);
    await tester.enterText(find.byType(TextField), 'new text');
    await tester.tap(
      find.byKey(ValueKey('story-card-text-input-color-$selectedColorIndex')),
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
    final save = tester.widget<IconButton>(
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

    IconButton saveButton() => tester.widget<IconButton>(
      find.byKey(const ValueKey('story-card-editor-save')),
    );

    expect(saveButton().onPressed, isNull);

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    await tester.dragFrom(center - const Offset(30, 30), const Offset(60, 60));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('story-card-drawing-done')));
    await tester.pump();

    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('drawing completion has no tool selection background', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());
    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    final doneFinder = find.byKey(const ValueKey('story-card-drawing-done'));
    final done = tester.widget<IconButton>(doneFinder);
    expect(done.color, Colors.white);
    expect(
      done.style?.backgroundColor?.resolve({}) ?? Colors.transparent,
      Colors.transparent,
    );
    expect(done.style?.side?.resolve({}) ?? BorderSide.none, BorderSide.none);
    expect(tester.getSize(doneFinder), const Size.square(48));
    expect(done.tooltip, '그리기 완료');

    final pen = tester.widget<IconButton>(
      find.byKey(const ValueKey('story-card-drawing-pen')),
    );
    expect(pen.style?.backgroundColor?.resolve({}), Colors.white);
    await tester.tap(doneFinder);
    await tester.pump();
    expect(find.byType(StoryCardDrawingControls), findsNothing);
    expect(
      find.byKey(const ValueKey('story-card-editor-header')),
      findsOneWidget,
    );
  });

  testWidgets('drawing mode uses immersive edge controls without crop', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    expect(find.byKey(const ValueKey('story-card-drawing-eraser')), findsOne);
    expect(find.byKey(const ValueKey('story-card-drawing-undo')), findsOne);
    expect(
      find.byKey(const ValueKey('story-card-drawing-eyedropper')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('story-card-drawing-done')), findsOne);
    expect(
      find.byKey(const ValueKey('story-card-drawing-top-controls')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('story-card-drawing-width-control')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('story-card-drawing-color-palette')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('story-card-editor-header')),
      findsNothing,
    );
    expect(find.byIcon(Icons.text_fields), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('story-card-drawing-done')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('그리기 완료'), findsOneWidget);
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

    final screenWidth = tester.getSize(find.byType(Scaffold)).width;
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('story-card-drawing-top-controls')),
          )
          .width,
      screenWidth,
    );
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('story-card-drawing-header-surface')),
          )
          .color,
      Colors.transparent,
    );
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('story-card-drawing-toolbar')),
          )
          .color,
      Colors.transparent,
    );
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(
              const ValueKey('story-card-drawing-style-controls-surface'),
            ),
          )
          .color,
      Colors.transparent,
    );
    expect(
      tester
          .widget<AppDrawingToolbar>(find.byType(AppDrawingToolbar))
          .showContrastShadow,
      isTrue,
    );
    expect(
      tester
          .widget<AppDrawingStyleControls>(find.byType(AppDrawingStyleControls))
          .showContrastShadow,
      isTrue,
    );
    final doneIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('story-card-drawing-done')),
        matching: find.byIcon(Icons.check_rounded),
      ),
    );
    expect(doneIcon.shadows, isNotEmpty);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('story-card-drawing-color-palette')),
          )
          .width,
      screenWidth,
    );
  });

  testWidgets('eyedropper samples the card and restores drawing controls', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingRedPhotoDraft());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();
    final drawingCanvas = tester.getRect(
      find.byKey(const ValueKey('story-card-editor-canvas')),
    );
    await openColorPicker(tester, buttonPrefix: 'story-card-drawing');

    final sampler = find.byKey(
      const ValueKey('story-card-drawing-eyedropper-overlay'),
    );
    expect(sampler, findsOneWidget);
    expect(
      find.byKey(const ValueKey('story-card-drawing-top-controls')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('story-card-drawing-color-palette')),
      findsNothing,
    );
    expect(find.byType(AppDrawingWidthSlider), findsNothing);

    final sampledCanvas = tester.widget<AppColorSampler>(sampler).canvasRect;
    expect(sampledCanvas, drawingCanvas);
    final gesture = await tester.startGesture(sampledCanvas.center);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(sampler, findsNothing);
    final controls = tester.widget<StoryCardDrawingControls>(
      find.byType(StoryCardDrawingControls),
    );
    expect(controls.selectedColor, const Color(0xFFFF0000));
    expect(controls.selectedTool, StoryCardDrawingTool.pen);
    expect(
      tester.getRect(find.byKey(const ValueKey('story-card-editor-canvas'))),
      drawingCanvas,
    );
  });

  testWidgets('back cancels eyedropper without leaving drawing mode', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingRedPhotoDraft());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();
    await openColorPicker(tester, buttonPrefix: 'story-card-drawing');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('story-card-drawing-eyedropper-overlay')),
      findsNothing,
    );
    expect(find.byType(StoryCardDrawingControls), findsOneWidget);
  });

  testWidgets('undo removes the last completed drawing stroke', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    IconButton saveButton() => tester.widget<IconButton>(
      find.byKey(const ValueKey('story-card-editor-save')),
    );

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    await tester.dragFrom(center - const Offset(30, 0), const Offset(60, 0));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('story-card-drawing-done')));
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-card-drawing-undo')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('story-card-drawing-done')));
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

  testWidgets('drawing done restores photo adjustment entry', (tester) async {
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
    await tester.tapAt(tester.getCenter(canvas));
    await _pumpPhotoAdjustmentRoute(tester);

    expect(find.byType(StoryCardPhotoAdjustmentScreen), findsOneWidget);
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

  testWidgets('does not transform a photo directly on the card canvas', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

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
    await first.moveBy(const Offset(30, 40));
    await second.moveBy(const Offset(30, 40));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    final transform = _backgroundTransform(tester);
    expect(transform, const StoryCardBackgroundTransform.initial());
    expect(find.byType(StoryCardPhotoAdjustmentScreen), findsNothing);
  });

  testWidgets('opens photo adjustment instead of moving with one pointer', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    await tester.dragFrom(center, const Offset(30, 40));
    await tester.pump();

    expect(
      _backgroundTransform(tester),
      const StoryCardBackgroundTransform.initial(),
    );

    await tester.tapAt(center);
    await _pumpPhotoAdjustmentRoute(tester);

    expect(find.byType(StoryCardPhotoAdjustmentScreen), findsOneWidget);
  });

  testWidgets(
    'returns to photo adjustment entry after text input is cancelled',
    (tester) async {
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
      final photoPoint = Offset(
        canvasRect.left + 30,
        canvasRect.top + canvasRect.height * 0.25,
      );
      expect(
        find.byKey(const ValueKey('story-card-text-input-overlay')),
        findsNothing,
      );

      await tester.tapAt(photoPoint);
      await _pumpPhotoAdjustmentRoute(tester);

      expect(find.byType(StoryCardPhotoAdjustmentScreen), findsOneWidget);
    },
  );
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

Future<void> _pumpPhotoAdjustmentRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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

StoryCardDraft _photoDraftForType(StoryCardType type, {int? existingRevision}) {
  final photo = image.Image(width: 4, height: 4);
  return StoryCardDraft(
    scene: StoryCardScene.empty(cardType: type),
    backgroundImageBytes: Uint8List.fromList(image.encodePng(photo)),
    existingRevision: existingRevision,
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

StoryCardFilmState _filmFromPainter(WidgetTester tester) {
  final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: canvas, matching: find.byType(CustomPaint)).first,
  );
  final dynamic painter = customPaint.painter;
  return painter.film as StoryCardFilmState;
}

String? _captionFromPainter(WidgetTester tester) {
  final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: canvas, matching: find.byType(CustomPaint)).first,
  );
  final dynamic painter = customPaint.painter;
  return painter.caption as String?;
}

StoryCardAppearance _appearanceFromPainter(WidgetTester tester) {
  final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
  final customPaint = tester.widget<CustomPaint>(
    find.descendant(of: canvas, matching: find.byType(CustomPaint)).first,
  );
  final dynamic painter = customPaint.painter;
  return (painter.scene as StoryCardScene).appearance;
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
