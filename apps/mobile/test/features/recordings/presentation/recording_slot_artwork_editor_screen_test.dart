import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_canvas.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/recordings/application/couple_recording_overview_controller.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';
import 'package:vinscent/features/recordings/presentation/recording_slot_artwork_editor_screen.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  testWidgets('saves a slot drawing as WebP and gzip artifacts', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository();
    final router = GoRouter(
      initialLocation: '/home/recordings/slot-1/artwork',
      routes: [
        GoRoute(
          path: '/home/recordings/slot-1/artwork',
          builder: (context, state) =>
              const RecordingSlotArtworkEditorScreen(slotId: 'slot-1'),
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
          coupleRecordingOverviewControllerProvider.overrideWithBuild(
            (ref, notifier) => repository.overview,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('슬롯 그림'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
    await tester.pump();
    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await _waitForRoute(tester, router, '/home/recordings');

    expect(repository.savedSlotId, 'slot-1');
    expect(repository.savedSlotRevision, 4);
    expect(repository.savedPreviewBytes!.take(4), [82, 73, 70, 70]);
    expect(gzip.decode(repository.savedDrawingDataBytes!), isNotEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/home/recordings');
  });

  testWidgets('creates a slot with its title and drawing in one flow', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository.creating();
    final router = _createRouter(
      const RecordingSlotArtworkEditorScreen.create(slotIndex: 1),
    );

    await _pumpEditor(tester, repository: repository, router: router);

    expect(find.text('슬롯 만들기'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('recording-slot-title-field')),
      '우리 녹음',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await _waitForRoute(tester, router, '/home/recordings');

    expect(repository.saveSlotCallCount, 1);
    expect(repository.savedSlotIndex, 1);
    expect(repository.savedSlotTitle, '우리 녹음');
    expect(repository.savedSlotId, 'created-slot-1');
    expect(repository.savedSlotRevision, 1);
    expect(repository.savedPreviewBytes, isNotEmpty);
    expect(repository.savedDrawingDataBytes, isNotEmpty);
  });

  testWidgets(
    'retries only artwork when artwork upload fails after slot creation',
    (tester) async {
      final repository = _FakeRecordingRepository.creating(
        failFirstArtworkSave: true,
      );
      final router = _createRouter(
        const RecordingSlotArtworkEditorScreen.create(slotIndex: 1),
      );

      await _pumpEditor(tester, repository: repository, router: router);
      await tester.enterText(
        find.byKey(const ValueKey('recording-slot-title-field')),
        '다시 저장',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(AppDrawingCanvas), const Offset(80, 40));
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.text('저장'));
      });
      await _waitForCondition(
        tester,
        () => repository.artworkSaveCallCount == 1,
      );

      expect(find.text('그림 저장 권한을 확인해 주세요.'), findsOneWidget);
      expect(repository.saveSlotCallCount, 1);
      expect(repository.artworkSaveCallCount, 1);
      expect(
        router.routeInformationProvider.value.uri.path,
        contains('create'),
      );

      await tester.runAsync(() async {
        await tester.tap(find.text('저장'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await _waitForRoute(tester, router, '/home/recordings');

      expect(repository.saveSlotCallCount, 1);
      expect(repository.artworkSaveCallCount, 2);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/home/recordings',
      );
    },
  );
}

GoRouter _createRouter(Widget editor) {
  return GoRouter(
    initialLocation: '/home/recordings/create/1',
    routes: [
      GoRoute(
        path: '/home/recordings/create/1',
        builder: (context, state) => Scaffold(body: editor),
      ),
      GoRoute(
        path: '/home/recordings',
        builder: (context, state) => const Text('library'),
      ),
    ],
  );
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required _FakeRecordingRepository repository,
  required GoRouter router,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(),
        ),
        coupleRecordingRepositoryProvider.overrideWithValue(repository),
        coupleRecordingOverviewControllerProvider.overrideWithBuild(
          (ref, notifier) => repository.overview,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _waitForRoute(
  WidgetTester tester,
  GoRouter router,
  String path,
) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (router.routeInformationProvider.value.uri.path != path &&
      DateTime.now().isBefore(timeoutAt)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> _waitForCondition(
  WidgetTester tester,
  bool Function() condition,
) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(timeoutAt)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump();
}

TextButton _saveButton(WidgetTester tester) {
  return tester.widget<TextButton>(find.widgetWithText(TextButton, '저장'));
}

class _FakeRecordingRepository implements CoupleRecordingRepository {
  _FakeRecordingRepository()
    : overview = CoupleRecordingOverview(
        slotLimit: 1,
        currentRecording: null,
        savedSlots: [_slot()],
      ),
      failFirstArtworkSave = false;

  _FakeRecordingRepository.creating({this.failFirstArtworkSave = false})
    : overview = CoupleRecordingOverview(
        slotLimit: 1,
        currentRecording: _currentRecording(),
        savedSlots: const [],
      );

  final CoupleRecordingOverview overview;
  final bool failFirstArtworkSave;
  String? savedSlotId;
  int? savedSlotRevision;
  int? savedSlotIndex;
  String? savedSlotTitle;
  Uint8List? savedPreviewBytes;
  Uint8List? savedDrawingDataBytes;
  int saveSlotCallCount = 0;
  int artworkSaveCallCount = 0;

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
    artworkSaveCallCount += 1;
    if (failFirstArtworkSave && artworkSaveCallCount == 1) {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.storage,
      );
    }
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
  Future<CoupleRecordingSlotSaveResult> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {
    saveSlotCallCount += 1;
    savedSlotIndex = slotIndex;
    savedSlotTitle = title;
    return CoupleRecordingSlotSaveResult(
      slotId: 'created-slot-$slotIndex',
      slotIndex: slotIndex,
      slotRevision: expectedSlotRevision ?? 1,
    );
  }

  @override
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
    String? recordingId,
    bool resumeExistingUpload = false,
  }) async {}

  @override
  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) async {}
}

CurrentCoupleRecording _currentRecording() {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CurrentCoupleRecording(
    recordingId: 'recording-current',
    senderUserId: 'user-id',
    durationMs: 1000,
    recordedAt: timestamp,
    revision: 1,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/current.m4a',
  );
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
