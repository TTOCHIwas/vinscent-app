import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/features/characters/data/couple_character.dart';
import 'package:vinscent/features/characters/data/couple_character_repository.dart';
import 'package:vinscent/features/characters/presentation/character_editor_screen.dart';
import 'package:vinscent/features/characters/presentation/widgets/character_canvas.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';

void main() {
  testWidgets('saves drawn character as PNG and drawing JSON', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    expect(_saveButton(tester).onPressed, isNull);

    await tester.drag(find.byType(CharacterCanvas), const Offset(80, 40));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.savedImageBytes, isNotNull);
    expect(repository.savedDrawingDataJson, contains('"strokes"'));
    expect(repository.savedImageBytes!.take(4), [137, 80, 78, 71]);
  });

  testWidgets('enables save after drawing a dot', (tester) async {
    final repository = _FakeCoupleCharacterRepository();

    await _pumpCharacterEditor(tester, repository);

    expect(_saveButton(tester).onPressed, isNull);

    await tester.tap(find.byType(CharacterCanvas));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);
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
          initialLocation: '/home/character',
          routes: [
            GoRoute(
              path: '/home/character',
              builder: (context, state) => const CharacterEditorScreen(),
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

final _activeCouple = Couple(
  id: 'couple-id',
  inviteCode: 'ABC234',
  userAId: 'user-id',
  userBId: 'partner-id',
  relationshipStartDate: DateTime(2026, 5, 30),
  timezone: 'Asia/Seoul',
  status: CoupleStatus.active,
  connectedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
