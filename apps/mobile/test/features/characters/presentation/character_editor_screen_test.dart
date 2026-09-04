import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/drawing/app_drawing_style.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_canvas.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_style_controls.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_toolbar.dart';
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';
import 'package:vinscent/core/presentation/widgets/app_svg_icon.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_failure.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/characters/presentation/character_editor_screen.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/data/safety_report_repository.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/color_picker_test_helpers.dart';
import '../../../support/drawing_layout_test_helpers.dart';

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(900, 1200),
    const Size(800, 360),
  ]) {
    testWidgets('shared drawing layout for character on $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpCharacterEditor(tester, _FakeCoupleCharacterRepository());
      expect(find.text('캐릭터 그리기'), findsNothing);
      expectSharedDrawingLayout(
        tester,
        keyPrefix: 'character-drawing',
        canvas: find.byType(AppDrawingCanvas),
      );
      expect(
        find.byKey(const ValueKey('character-editor-save')),
        findsOneWidget,
      );
      expect(find.byTooltip('뒤로가기'), findsOneWidget);
    });
  }

  testWidgets('width preview stays above the bottom drawing tools', (
    tester,
  ) async {
    await _pumpCharacterEditor(tester, _FakeCoupleCharacterRepository());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await tester.pump();
    final preview = tester.getRect(
      find.byKey(const Key('drawing-width-preview')),
    );
    final tools = tester.getRect(
      find.byKey(const Key('character-drawing-toolbar')),
    );
    await gesture.up();
    await tester.pump();
    expect(preview.bottom, lessThanOrEqualTo(tools.top - 8));
  });

  testWidgets('samples the character without adding or saving strokes', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository();
    await _pumpCharacterEditor(tester, repository);
    await tester.tap(find.byKey(const ValueKey('character-drawing-color-3')));
    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 0));
    await tester.pump();
    final strokes = tester
        .widget<AppDrawingCanvas>(find.byType(AppDrawingCanvas))
        .strokes;
    await tester.tap(find.byKey(const ValueKey('character-drawing-eraser')));
    await tester.pump();
    final sampler = await openColorPicker(
      tester,
      buttonPrefix: 'character-drawing',
    );
    await tester.tapAt(sampler.canvasRect.center);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppDrawingStyleControls>(find.byType(AppDrawingStyleControls))
          .selectedColor,
      AppDrawingStyle.colorPalette[3],
    );
    expect(
      tester.widget<AppDrawingCanvas>(find.byType(AppDrawingCanvas)).strokes,
      strokes,
    );
    expect(repository.savedImageBytes, isNull);
  });

  testWidgets('saves drawn character as PNG and drawing JSON', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);
    final router = GoRouter.of(
      tester.element(find.byType(CharacterEditorScreen)),
    );

    expect(_saveButton(tester).onPressed, isNull);

    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('character-editor-save')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('저장'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('character-editor-save')));
    await _waitForRoute(tester, router, '/settings');
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.savedImageBytes, isNotNull);
    expect(repository.savedDrawingDataJson, contains('"strokes"'));
    expect(repository.savedImageBytes!.take(4), [137, 80, 78, 71]);
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('enables save after drawing a dot', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.byType(AppDrawingCanvas));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('reports a partner-updated character', (tester) async {
    final repository = _FakeCoupleCharacterRepository(
      currentCharacter: _partnerCharacter,
      drawingDataJson: _drawingDataJson,
    );
    final safetyRepository = _FakeSafetyReportRepository();

    await _pumpCharacterEditor(
      tester,
      repository,
      safetyReportRepository: safetyRepository,
    );

    final reportButton = find.byKey(const ValueKey('character-editor-report'));
    expect(reportButton, findsOneWidget);

    await tester.tap(reportButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('safety-report-reason-inappropriate')),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
    await tester.tap(find.byKey(const Key('safety-report-submit')));
    await tester.pumpAndSettle();

    expect(
      safetyRepository.requests.single.target,
      SafetyReportTarget(
        type: SafetyReportTargetType.character,
        id: _activeCouple.id,
      ),
    );
  });

  testWidgets('does not report a current-user-updated character', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository(
      currentCharacter: _character,
      drawingDataJson: _drawingDataJson,
    );

    await _pumpCharacterEditor(tester, repository);

    expect(find.byKey(const ValueKey('character-editor-report')), findsNothing);
  });

  testWidgets(
    'describes storage failures without assuming a permission issue',
    (tester) async {
      final repository = _FakeCoupleCharacterRepository(
        saveError: const CoupleCharacterRepositoryException(
          CoupleCharacterFailureReason.storage,
          'storage request failed',
        ),
      );

      await _pumpCharacterEditor(tester, repository);
      await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('character-editor-save')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      expect(find.text('캐릭터 파일을 저장하지 못했어요.'), findsOneWidget);
      expect(find.text('캐릭터 저장 권한을 확인해 주세요.'), findsNothing);
    },
  );

  testWidgets('undo removes completed strokes from newest to oldest', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
    await tester.drag(find.byType(AppDrawingCanvas), const Offset(-60, 30));
    await tester.pump();

    final undoButton = find.byKey(const ValueKey('character-drawing-undo'));
    expect(undoButton, findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(undoButton);
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(undoButton);
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNull);
    expect(tester.widget<IconButton>(undoButton).onPressed, isNull);
  });

  testWidgets('centers the canvas in the area above fixed drawing controls', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository();
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCharacterEditor(tester, repository);

    final canvas = find.byType(AppDrawingCanvas);
    final canvasRegion = find.byKey(
      const ValueKey('character-drawing-canvas-region'),
    );
    final toolbar = find.byKey(const ValueKey('character-drawing-toolbar'));

    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(canvasRegion, findsOneWidget);
    expect(toolbar, findsOneWidget);
    expect(
      tester.getCenter(canvas).dy,
      closeTo(tester.getCenter(canvasRegion).dy, 0.01),
    );
    expect(
      find.byKey(const ValueKey('character-drawing-clear')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the shared rectangular eraser icon', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    final eraserButton = find.byKey(const ValueKey('character-drawing-eraser'));
    final eraserIcon = find.descendant(
      of: eraserButton,
      matching: find.byType(AppSvgIcon),
    );

    expect(eraserIcon, findsOneWidget);
    expect(
      tester.widget<AppSvgIcon>(eraserIcon).assetName,
      'assets/icons/eraser_black.svg',
    );
  });

  testWidgets('clears current drawing after confirmation', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('character-drawing-clear')));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
    await tester.pumpAndSettle();

    expect(_saveButton(tester).onPressed, isNull);

    await tester.ensureVisible(find.byType(AppDrawingCanvas));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(AppDrawingCanvas), const Offset(60, 30));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('saves selected slider stroke width', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(
      AppDrawingStyle.thickStrokeWidth,
    );
    await tester.pump();

    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('character-editor-save')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final drawingJson =
        jsonDecode(repository.savedDrawingDataJson!) as Map<String, dynamic>;
    final strokes = drawingJson['strokes'] as List<dynamic>;
    final stroke = Map<String, dynamic>.from(strokes.first as Map);

    expect(
      (stroke['width'] as num).toDouble(),
      AppDrawingStyle.thickStrokeWidth,
    );
  });

  testWidgets('returns to settings when back is pressed from a direct route', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets('uses the shared drawing toolbar and standard back icon size', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    expect(find.byType(AppDrawingToolbar), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.descendant(
              of: find.byType(AppBackButton),
              matching: find.byType(IconButton),
            ),
          )
          .iconSize,
      24,
    );
  });

  testWidgets('returns to the page that opened the editor', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleControllerProvider.overrideWithBuild(
            (ref, notifier) async => _activeCouple,
          ),
          coupleCharacterRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/home',
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => TextButton(
                  onPressed: () => context.push('/settings/character'),
                  child: const Text('open editor'),
                ),
              ),
              GoRoute(
                path: '/settings/character',
                builder: (context, state) =>
                    const Scaffold(body: CharacterEditorScreen()),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const Text('settings'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.text('open editor'), findsOneWidget);
    expect(find.text('settings'), findsNothing);
  });

  testWidgets('confirms before discarding unsaved character changes', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);
    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
    await tester.pump();

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('그림을 저장하지 않고 나갈까요?'), findsOneWidget);
    expect(find.text('계속 그리기'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);

    await tester.tap(find.byKey(const Key('app-confirmation-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterEditorScreen), findsOneWidget);

    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsOneWidget);
  });

  testWidgets(
    'blocks editing and offers retry when saved drawing fails to load',
    (tester) async {
      final repository = _FakeCoupleCharacterRepository(
        currentCharacter: _character,
        drawingDataJson: _drawingDataJson,
        fetchDrawingError: StateError('load failed'),
      );

      await _pumpCharacterEditor(tester, repository);

      expect(find.text('캐릭터를 불러오지 못했어요.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '다시 시도'), findsOneWidget);
      expect(find.byType(AppDrawingCanvas), findsNothing);
      expect(_saveButton(tester).onPressed, isNull);

      repository.fetchDrawingError = null;
      await tester.tap(find.widgetWithText(TextButton, '다시 시도'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDrawingCanvas), findsOneWidget);
      expect(find.text('캐릭터를 불러오지 못했어요.'), findsNothing);
      expect(repository.fetchDrawingCallCount, 2);
    },
  );

  testWidgets('uses the default character when initial setup is skipped', (
    tester,
  ) async {
    final characterRepository = _FakeCoupleCharacterRepository();
    final coupleRepository = _FakeCoupleRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleControllerProvider.overrideWithBuild(
            (ref, notifier) async => _initialSetupCouple,
          ),
          coupleRepositoryProvider.overrideWithValue(coupleRepository),
          coupleCharacterRepositoryProvider.overrideWithValue(
            characterRepository,
          ),
          profileControllerProvider.overrideWithBuild(
            (ref, notifier) async => _profile,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/couple/character',
            routes: [
              GoRoute(
                path: '/couple/character',
                builder: (context, state) =>
                    const CharacterEditorScreen.initialSetup(),
              ),
              GoRoute(
                path: '/home',
                builder: (context, state) => const Text('home'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '건너뛰기'));
    await tester.pumpAndSettle();

    expect(coupleRepository.didUseDefaultCharacter, isTrue);
    expect(find.text('home'), findsOneWidget);
  });
}

Future<void> _pumpCharacterEditor(
  WidgetTester tester,
  CoupleCharacterRepository repository, {
  SafetyReportRepository? safetyReportRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => _activeCouple,
        ),
        coupleCharacterRepositoryProvider.overrideWithValue(repository),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        if (safetyReportRepository != null)
          safetyReportRepositoryProvider.overrideWithValue(
            safetyReportRepository,
          ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/settings/character',
          routes: [
            GoRoute(
              path: '/settings/character',
              builder: (context, state) =>
                  const Scaffold(body: CharacterEditorScreen()),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const Text('settings'),
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) => const Text('home'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

IconButton _saveButton(WidgetTester tester) {
  return tester.widget<IconButton>(
    find.byKey(const ValueKey('character-editor-save')),
  );
}

Future<void> _waitForRoute(
  WidgetTester tester,
  GoRouter router,
  String path,
) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 2));
  while (router.routeInformationProvider.value.uri.path != path &&
      DateTime.now().isBefore(timeoutAt)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

class _FakeCoupleCharacterRepository implements CoupleCharacterRepository {
  _FakeCoupleCharacterRepository({
    this.saveError,
    this.currentCharacter,
    this.drawingDataJson,
    this.fetchDrawingError,
  });

  final Object? saveError;
  final CoupleCharacter? currentCharacter;
  final String? drawingDataJson;
  Object? fetchDrawingError;
  int fetchDrawingCallCount = 0;
  Uint8List? savedImageBytes;
  String? savedDrawingDataJson;

  @override
  Future<CoupleCharacter?> fetchCurrentCharacter() async {
    return currentCharacter;
  }

  @override
  Future<String?> fetchDrawingData(CoupleCharacter character) async {
    fetchDrawingCallCount++;
    if (fetchDrawingError case final error?) {
      throw error;
    }
    return drawingDataJson;
  }

  @override
  Future<CoupleCharacter> saveCharacter({
    required String coupleId,
    required Uint8List imageBytes,
    required String drawingDataJson,
  }) async {
    if (saveError != null) {
      throw saveError!;
    }

    savedImageBytes = imageBytes;
    savedDrawingDataJson = drawingDataJson;

    return CoupleCharacter(
      coupleId: coupleId,
      imagePath: CoupleCharacterStoragePaths.imagePathFor(coupleId),
      drawingDataPath: CoupleCharacterStoragePaths.drawingDataPathFor(coupleId),
      updatedBy: 'user-id',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      imageUrl: 'https://example.com/current.png',
    );
  }
}

class _FakeSafetyReportRepository implements SafetyReportRepository {
  final requests = <SafetyReportRequest>[];

  @override
  Future<void> submit(SafetyReportRequest request) async {
    requests.add(request);
  }
}

class _FakeCoupleRepository implements CoupleRepository {
  bool didUseDefaultCharacter = false;

  @override
  Future<Couple?> fetchCurrentCouple() async => _completedSetupCouple;

  @override
  Future<Couple> useDefaultCharacter() async {
    didUseDefaultCharacter = true;
    return _completedSetupCouple;
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
  Future<Couple> disconnectCouple() => throw UnimplementedError();

  @override
  Future<void> deleteDisconnectedArchiveNow() => throw UnimplementedError();
}

final _activeCouple = activeCouple();
final _initialSetupCouple = activeCouple(
  userAId: 'partner-id',
  userBId: 'user-id',
  characterSetupStatus: CoupleCharacterSetupStatus.pending,
);
final _completedSetupCouple = activeCouple(
  userAId: 'partner-id',
  userBId: 'user-id',
  characterSetupStatus: CoupleCharacterSetupStatus.defaultCharacter,
);
final _profile = UserProfile(
  id: 'user-id',
  displayName: 'User',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _character = CoupleCharacter(
  coupleId: _activeCouple.id,
  imagePath: CoupleCharacterStoragePaths.imagePathFor(_activeCouple.id),
  drawingDataPath: CoupleCharacterStoragePaths.drawingDataPathFor(
    _activeCouple.id,
  ),
  updatedBy: 'user-id',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _partnerCharacter = CoupleCharacter(
  coupleId: _activeCouple.id,
  imagePath: CoupleCharacterStoragePaths.imagePathFor(_activeCouple.id),
  drawingDataPath: CoupleCharacterStoragePaths.drawingDataPathFor(
    _activeCouple.id,
  ),
  updatedBy: 'partner-id',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

const _drawingDataJson =
    '{"version":1,"strokes":[{"tool":"pen","color":"#ff111111",'
    '"width":8.0,"points":[{"x":0.2,"y":0.2},{"x":0.8,"y":0.8}]}]}';
