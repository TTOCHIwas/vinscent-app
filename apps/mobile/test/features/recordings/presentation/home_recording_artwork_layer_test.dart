import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/recordings/application/couple_recording_overview_controller.dart';
import 'package:vinscent/features/recordings/application/recording_slot_placement_session.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';
import 'package:vinscent/features/recordings/presentation/widgets/home_recording_artwork_layer.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  testWidgets('uses a larger artwork and preserves an upper-stage position', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository(
      _overview(
        slot: _slot(
          placement: const CoupleRecordingSlotPlacement(
            normalizedX: 0.5,
            normalizedY: 0.1,
            revision: 1,
          ),
        ),
      ),
    );
    await _pumpLayer(tester, repository);

    final layer = find.byType(HomeRecordingArtworkLayer);
    final artwork = find.byKey(const ValueKey('home-recording-artwork-slot-1'));
    final localCenter = tester.getCenter(artwork) - tester.getTopLeft(layer);

    expect(tester.getSize(artwork).width, greaterThanOrEqualTo(72));
    expect(localCenter.dx, closeTo(168, 0.1));
    expect(localCenter.dy, closeTo(tester.getSize(layer).height * 0.1, 0.1));
  });

  testWidgets('uses the character pulse instead of a flashing border', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository(
      _overview(
        slot: _slot(
          placement: const CoupleRecordingSlotPlacement(
            normalizedX: 0.5,
            normalizedY: 0.5,
            revision: 1,
          ),
        ),
      ),
    );
    final container = await _pumpLayer(tester, repository);

    container
        .read(recordingSlotPlacementSessionProvider.notifier)
        .begin('slot-1');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 160));

    final pulse = tester.widget<ScaleTransition>(
      find.byKey(const ValueKey('home-recording-artwork-pulse-slot-1')),
    );
    expect(pulse.scale.value, greaterThan(1));

    final artwork = find.byKey(const ValueKey('home-recording-artwork-slot-1'));
    final hasBorder = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: artwork,
            matching: find.byType(AnimatedContainer),
          ),
        )
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .any((decoration) => decoration.border != null);
    expect(hasBorder, isFalse);
  });

  testWidgets('consumes a library session and creates one valid placement', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository(
      _overview(slot: _slot(placement: null)),
    );
    final container = await _pumpLayer(tester, repository);

    container
        .read(recordingSlotPlacementSessionProvider.notifier)
        .begin('slot-1');
    await tester.pump();
    await _waitUntil(tester, () => repository.upsertedSlotId != null);
    await tester.pump();

    expect(repository.upsertedSlotId, 'slot-1');
    expect(repository.upsertedExpectedRevision, isNull);
    expect(repository.upsertedX, inInclusiveRange(0, 1));
    expect(repository.upsertedY, inInclusiveRange(0, 1));
    expect(container.read(recordingSlotPlacementSessionProvider), isNull);
  });

  testWidgets(
    'keeps newly placed artwork visible while persistence is pending',
    (tester) async {
      final upsertBarrier = Completer<void>();
      final repository = _FakeRecordingRepository(
        _overview(slot: _slot(placement: null)),
        upsertBarrier: upsertBarrier,
      );
      final container = await _pumpLayer(tester, repository);

      container
          .read(recordingSlotPlacementSessionProvider.notifier)
          .begin('slot-1');
      await tester.pump();
      await _waitUntil(tester, () => repository.upsertedSlotId != null);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('home-recording-artwork-slot-1')),
        findsOneWidget,
      );

      upsertBarrier.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('keeps artwork visible while mutation refresh is pending', (
    tester,
  ) async {
    final fetchBarrier = Completer<void>();
    final repository = _FakeRecordingRepository(
      _overview(slot: _slot(placement: null)),
      fetchBarrier: fetchBarrier,
    );
    final container = await _pumpLayer(tester, repository);

    container
        .read(recordingSlotPlacementSessionProvider.notifier)
        .begin('slot-1');
    await tester.pump();
    await _waitUntil(tester, () => repository.fetchStarted);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('home-recording-artwork-slot-1')),
      findsOneWidget,
    );

    fetchBarrier.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('dragging onto trash removes only the home placement', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository(
      _overview(
        slot: _slot(
          placement: const CoupleRecordingSlotPlacement(
            normalizedX: 0.08,
            normalizedY: 0.72,
            revision: 3,
          ),
        ),
      ),
    );
    await _pumpLayer(tester, repository);

    final artwork = find.byKey(const ValueKey('home-recording-artwork-slot-1'));
    final gesture = await tester.startGesture(tester.getCenter(artwork));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();

    final trash = find.byKey(
      const ValueKey('home-recording-artwork-trash-target'),
    );
    expect(trash, findsOneWidget);
    await gesture.moveTo(tester.getCenter(trash));
    await tester.pump();

    expect(
      tester
          .widget<Icon>(
            find.byKey(const ValueKey('home-recording-artwork-trash-icon')),
          )
          .color,
      AppColors.actionPrimary,
    );

    await gesture.up();
    await _waitUntil(tester, () => repository.deletedSlotId != null);

    expect(repository.deletedSlotId, 'slot-1');
    expect(repository.deletedPlacementRevision, 3);
    expect(repository.deletedLibrarySlot, isFalse);
  });

  testWidgets('stationary long press replaces slot audio with current audio', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository(
      _overview(
        currentRecording: _currentRecording(),
        slot: _slot(
          placement: const CoupleRecordingSlotPlacement(
            normalizedX: 0.08,
            normalizedY: 0.72,
            revision: 1,
          ),
        ),
      ),
    );
    await _pumpLayer(tester, repository);

    await tester.longPress(
      find.byKey(const ValueKey('home-recording-artwork-slot-1')),
    );
    await _waitUntil(tester, () => repository.savedSlotIndex != null);

    expect(repository.savedSlotIndex, 1);
    expect(repository.savedSlotTitle, '첫 녹음');
    expect(repository.savedSlotRevision, 4);
  });

  testWidgets('overlapping artwork routes gestures to the highest z-index', (
    tester,
  ) async {
    final repository = _FakeRecordingRepository(
      _overviewWithSlots(
        currentRecording: _currentRecording(),
        slots: [
          _slot(
            slotId: 'front-slot',
            slotIndex: 2,
            placement: const CoupleRecordingSlotPlacement(
              normalizedX: 0.5,
              normalizedY: 0.5,
              revision: 1,
              zIndex: 4,
            ),
          ),
          _slot(
            slotId: 'back-slot',
            slotIndex: 1,
            placement: const CoupleRecordingSlotPlacement(
              normalizedX: 0.5,
              normalizedY: 0.5,
              revision: 1,
              zIndex: 1,
            ),
          ),
        ],
      ),
    );
    await _pumpLayer(tester, repository);

    await tester.longPress(
      find.byKey(const ValueKey('home-recording-artwork-front-slot')),
    );
    await _waitUntil(tester, () => repository.savedSlotIndex != null);

    expect(repository.savedSlotIndex, 2);
  });
}

Future<ProviderContainer> _pumpLayer(
  WidgetTester tester,
  _FakeRecordingRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(),
        ),
        coupleRecordingRepositoryProvider.overrideWithValue(repository),
        coupleRecordingOverviewControllerProvider.overrideWithBuild(
          (ref, notifier) => repository.currentOverview,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 336,
              height: 620,
              child: HomeRecordingArtworkLayer(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return ProviderScope.containerOf(
    tester.element(find.byType(HomeRecordingArtworkLayer)),
  );
}

Future<void> _waitUntil(WidgetTester tester, bool Function() condition) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(timeoutAt)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(condition(), isTrue);
}

class _FakeRecordingRepository implements CoupleRecordingRepository {
  _FakeRecordingRepository(
    this.currentOverview, {
    this.upsertBarrier,
    this.fetchBarrier,
  });

  CoupleRecordingOverview currentOverview;
  final Completer<void>? upsertBarrier;
  final Completer<void>? fetchBarrier;
  bool fetchStarted = false;
  String? upsertedSlotId;
  double? upsertedX;
  double? upsertedY;
  int? upsertedExpectedRevision;
  String? deletedSlotId;
  int? deletedPlacementRevision;
  bool deletedLibrarySlot = false;
  int? savedSlotIndex;
  String? savedSlotTitle;
  int? savedSlotRevision;

  @override
  Future<CoupleRecordingOverview> fetchOverview() async {
    fetchStarted = true;
    await fetchBarrier?.future;
    return currentOverview;
  }

  @override
  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) async {
    upsertedSlotId = slotId;
    upsertedX = normalizedX;
    upsertedY = normalizedY;
    upsertedExpectedRevision = expectedPlacementRevision;
    await upsertBarrier?.future;
    final oldSlot = currentOverview.savedSlots.single;
    currentOverview = _overview(
      currentRecording: currentOverview.currentRecording,
      slot: _slot(
        recordingId: oldSlot.recordingId,
        placement: CoupleRecordingSlotPlacement(
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          revision: (expectedPlacementRevision ?? 0) + 1,
        ),
      ),
    );
  }

  @override
  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  }) async {
    deletedSlotId = slotId;
    deletedPlacementRevision = expectedPlacementRevision;
    currentOverview = _overview(
      currentRecording: currentOverview.currentRecording,
      slot: _slot(placement: null),
    );
  }

  @override
  Future<CoupleRecordingSlotSaveResult> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {
    savedSlotIndex = slotIndex;
    savedSlotTitle = title;
    savedSlotRevision = expectedSlotRevision;
    return CoupleRecordingSlotSaveResult(
      slotId: 'slot-$slotIndex',
      slotIndex: slotIndex,
      slotRevision: expectedSlotRevision ?? 1,
    );
  }

  @override
  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) async {
    deletedLibrarySlot = true;
  }

  @override
  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  }) async => Uint8List(0);

  @override
  Future<void> openNextSlot() async {}

  @override
  Future<void> saveSlotArtwork({
    required String coupleId,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) async {}

  @override
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
  }) async {}
}

CoupleRecordingOverview _overview({
  required CoupleRecordingSlot slot,
  CurrentCoupleRecording? currentRecording,
}) {
  return CoupleRecordingOverview(
    slotLimit: 1,
    currentRecording: currentRecording,
    savedSlots: [slot],
  );
}

CoupleRecordingOverview _overviewWithSlots({
  required List<CoupleRecordingSlot> slots,
  CurrentCoupleRecording? currentRecording,
}) {
  return CoupleRecordingOverview(
    slotLimit: slots.length,
    currentRecording: currentRecording,
    savedSlots: slots,
  );
}

CoupleRecordingSlot _slot({
  String slotId = 'slot-1',
  int slotIndex = 1,
  String recordingId = 'saved-recording',
  required CoupleRecordingSlotPlacement? placement,
}) {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CoupleRecordingSlot(
    slotId: slotId,
    slotIndex: slotIndex,
    title: '첫 녹음',
    recordingId: recordingId,
    senderUserId: 'user-id',
    durationMs: 1000,
    recordedAt: timestamp,
    slotRevision: 4,
    createdByUserId: 'user-id',
    updatedByUserId: 'user-id',
    createdAt: timestamp,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/audio.m4a',
    artwork: const CoupleRecordingSlotArtwork(
      previewPath: 'couple/slots/slot/artworks/artifact/preview.webp',
      previewUrl: 'https://example.com/preview.webp',
      drawingDataPath: 'couple/slots/slot/artworks/artifact/drawing.json.gz',
      revision: 1,
    ),
    placement: placement,
  );
}

CurrentCoupleRecording _currentRecording() {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CurrentCoupleRecording(
    recordingId: 'current-recording',
    senderUserId: 'partner-id',
    durationMs: 1200,
    recordedAt: timestamp,
    revision: 2,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/current.m4a',
  );
}
