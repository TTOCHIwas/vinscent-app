import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/features/characters/presentation/widgets/character_canvas.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';
import 'package:vinscent/features/recordings/presentation/recording_slot_artwork_editor_screen.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  testWidgets('saves a slot drawing as WebP and gzip artifacts', (tester) async {
    final repository = _FakeRecordingRepository();
    final router = GoRouter(
      initialLocation: '/home/recordings/slot-1/artwork',
      routes: [
        GoRoute(
          path: '/home/recordings/slot-1/artwork',
          builder: (context, state) => const RecordingSlotArtworkEditorScreen(
            slotId: 'slot-1',
          ),
        ),
        GoRoute(
          path: '/home/recordings',
          builder: (context, state) => const Text('library'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleControllerProvider.overrideWithBuild(
            (ref, notifier) async => activeCouple(),
          ),
          coupleRecordingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('슬롯 그림'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.drag(find.byType(CharacterCanvas), const Offset(80, 40));
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(repository.savedSlotId, 'slot-1');
    expect(repository.savedSlotRevision, 4);
    expect(repository.savedPreviewBytes!.take(4), [82, 73, 70, 70]);
    expect(gzip.decode(repository.savedDrawingDataBytes!), isNotEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/home/recordings');
  });
}

TextButton _saveButton(WidgetTester tester) {
  return tester.widget<TextButton>(find.widgetWithText(TextButton, '저장'));
}

class _FakeRecordingRepository implements CoupleRecordingRepository {
  String? savedSlotId;
  int? savedSlotRevision;
  Uint8List? savedPreviewBytes;
  Uint8List? savedDrawingDataBytes;

  final overview = CoupleRecordingOverview(
    slotLimit: 1,
    currentRecording: null,
    savedSlots: [_slot()],
  );

  @override
  Future<CoupleRecordingOverview> fetchOverview() async => overview;

  @override
  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  }) async {
    throw StateError('No existing drawing');
  }

  @override
  Future<void> saveSlotArtwork({
    required String coupleId,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) async {
    savedSlotId = slotId;
    savedSlotRevision = expectedSlotRevision;
    savedPreviewBytes = previewBytes;
    savedDrawingDataBytes = drawingDataBytes;
  }

  @override
  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) async {}

  @override
  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  }) async {}

  @override
  Future<void> openNextSlot() async {}

  @override
  Future<void> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {}

  @override
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
  }) async {}

  @override
  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) async {}
}

CoupleRecordingSlot _slot() {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CoupleRecordingSlot(
    slotId: 'slot-1',
    slotIndex: 1,
    title: '첫 녹음',
    recordingId: 'recording-1',
    senderUserId: 'user-id',
    durationMs: 1000,
    recordedAt: timestamp,
    slotRevision: 4,
    createdByUserId: 'user-id',
    updatedByUserId: 'user-id',
    createdAt: timestamp,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/audio.m4a',
  );
}
