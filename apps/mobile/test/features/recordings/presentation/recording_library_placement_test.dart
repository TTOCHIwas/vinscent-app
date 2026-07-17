import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/recordings/application/couple_recording_overview_controller.dart';
import 'package:vinscent/features/recordings/application/recording_slot_placement_session.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';
import 'package:vinscent/features/recordings/presentation/recording_library_screen.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  testWidgets('long pressing an illustrated slot starts home placement', (
    tester,
  ) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: null,
      savedSlots: [_slot()],
    );
    final repository = _FakeRecordingRepository(overview);
    final router = GoRouter(
      initialLocation: '/home/recordings',
      routes: [
        GoRoute(
          path: '/home/recordings',
          builder: (context, state) => const RecordingLibraryScreen(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const Text('home')),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleControllerProvider.overrideWithBuild(
            (ref, notifier) async => activeCouple(),
          ),
          profileControllerProvider.overrideWithBuild(
            (ref, notifier) async => _profile,
          ),
          coupleRecordingRepositoryProvider.overrideWithValue(repository),
          coupleRecordingOverviewControllerProvider.overrideWithBuild(
            (ref, notifier) => overview,
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecordingLibraryScreen)),
    );

    await tester.longPress(
      find.byKey(const ValueKey('recording-library-slot-slot-1')),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(container.read(recordingSlotPlacementSessionProvider), 'slot-1');
  });
}

class _FakeRecordingRepository implements CoupleRecordingRepository {
  _FakeRecordingRepository(this.overview);

  final CoupleRecordingOverview overview;

  @override
  Future<CoupleRecordingOverview> fetchOverview() async => overview;

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
  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  }) async => Uint8List(0);

  @override
  Future<void> openNextSlot() async {}

  @override
  Future<void> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {}

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
    slotRevision: 1,
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
  );
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: '연인',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
