import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/presentation/widgets/app_svg_icon.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/characters/presentation/character_editor_screen.dart';
import 'package:vinscent/features/characters/presentation/widgets/character_canvas.dart';
import 'package:vinscent/features/characters/presentation/widgets/character_toolbar.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  testWidgets('saves drawn character as PNG and drawing JSON', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);
    final router = GoRouter.of(tester.element(find.text('캐릭터 그리기')));

    expect(_saveButton(tester).onPressed, isNull);

    await tester.drag(find.byType(CharacterCanvas), const Offset(80, 40));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('저장'));
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

    await tester.tap(find.byType(CharacterCanvas));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('undo removes completed strokes from newest to oldest', (
    tester,
  ) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    await tester.drag(find.byType(CharacterCanvas), const Offset(80, 40));
    await tester.drag(find.byType(CharacterCanvas), const Offset(-60, 30));
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

    final canvas = find.byType(CharacterCanvas);
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

    await tester.drag(find.byType(CharacterCanvas), const Offset(80, 40));
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('character-drawing-clear')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '삭제'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(_saveButton(tester).onPressed, isNull);

    await tester.ensureVisible(find.byType(CharacterCanvas));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CharacterCanvas), const Offset(60, 30));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('saves selected slider stroke width', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(
      characterThickStrokeWidth,
    );
    await tester.pump();

    await tester.drag(find.byType(CharacterCanvas), const Offset(80, 40));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final drawingJson =
        jsonDecode(repository.savedDrawingDataJson!) as Map<String, dynamic>;
    final strokes = drawingJson['strokes'] as List<dynamic>;
    final stroke = Map<String, dynamic>.from(strokes.first as Map);

    expect((stroke['width'] as num).toDouble(), characterThickStrokeWidth);
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
  CoupleCharacterRepository repository,
) async {
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
          initialLocation: '/settings/character',
          routes: [
            GoRoute(
              path: '/settings/character',
              builder: (context, state) => const CharacterEditorScreen(),
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

TextButton _saveButton(WidgetTester tester) {
  return tester.widget<TextButton>(find.widgetWithText(TextButton, '저장'));
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
  Uint8List? savedImageBytes;
  String? savedDrawingDataJson;

  @override
  Future<CoupleCharacter?> fetchCurrentCharacter() async {
    return null;
  }

  @override
  Future<String?> fetchDrawingData(CoupleCharacter character) async {
    return null;
  }

  @override
  Future<CoupleCharacter> saveCharacter({
    required String coupleId,
    required Uint8List imageBytes,
    required String drawingDataJson,
  }) async {
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
