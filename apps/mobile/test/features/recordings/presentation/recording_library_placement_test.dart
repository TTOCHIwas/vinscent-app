import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/recordings/application/couple_recording_overview_controller.dart';
import 'package:vinscent/features/recordings/application/recording_playback_controller.dart';
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
    final harness = await _pumpLibrary(tester, overview: overview);

    await tester.longPress(
      find.byKey(const ValueKey('recording-library-slot-slot-1')),
    );
    await tester.pumpAndSettle();

    expect(harness.router.routeInformationProvider.value.uri.path, '/home');
    expect(
      harness.container.read(recordingSlotPlacementSessionProvider),
      'slot-1',
    );
  });

  testWidgets('tapping a filled slot plays it without a separate play button', (
    tester,
  ) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: _currentRecording(),
      savedSlots: [_slot()],
    );
    final harness = await _pumpLibrary(tester, overview: overview);

    final slotRow = find.byKey(const ValueKey('recording-library-slot-slot-1'));
    expect(slotRow, findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);

    await tester.tap(slotRow);
    await tester.pump();

    expect(
      harness.playbackController.toggledTargetKey,
      'library-slot:slot-1:recording-1',
    );
  });

  testWidgets('slot actions are hidden in a more menu', (tester) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: _currentRecording(),
      savedSlots: [_slot()],
    );
    await _pumpLibrary(tester, overview: overview);

    expect(find.text('그림 수정'), findsNothing);
    expect(find.text('홈에 배치'), findsNothing);
    expect(find.text('현재 녹음으로 교체'), findsNothing);
    expect(find.text('삭제'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('recording-library-slot-menu-slot-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('그림 수정'), findsOneWidget);
    expect(find.text('홈에 배치'), findsOneWidget);
    expect(find.text('현재 녹음으로 교체'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('library rows have no border or artwork background color', (
    tester,
  ) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: _currentRecording(),
      savedSlots: [_slot()],
    );
    await _pumpLibrary(tester, overview: overview);

    final list = find.byKey(const ValueKey('recording-library-list'));
    expect(list, findsOneWidget);
    final borderedContainers = tester
        .widgetList<Container>(
          find.descendant(of: list, matching: find.byType(Container)),
        )
        .where((container) {
          final decoration = container.decoration;
          return decoration is BoxDecoration && decoration.border != null;
        });
    expect(borderedContainers, isEmpty);

    final artwork = find.byKey(const ValueKey('recording-slot-artwork-slot-1'));
    final coloredArtworkMaterials = tester
        .widgetList<Material>(
          find.ancestor(of: artwork, matching: find.byType(Material)),
        )
        .where((material) => material.color == const Color(0xFFF0F0F0));
    expect(coloredArtworkMaterials, isEmpty);
  });

  testWidgets('an empty slot uses an explicit add action', (tester) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 2,
      currentRecording: _currentRecording(),
      savedSlots: [_slot()],
    );
    await _pumpLibrary(tester, overview: overview);

    expect(find.text('현재 녹음 저장'), findsNothing);
    final addButton = find.byKey(
      const ValueKey('recording-library-empty-slot-save-2'),
    );
    expect(addButton, findsOneWidget);

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('슬롯 제목'), findsOneWidget);
  });
}

Future<_LibraryHarness> _pumpLibrary(
  WidgetTester tester, {
  required CoupleRecordingOverview overview,
}) async {
  final repository = _FakeRecordingRepository(overview);
  final playbackController = _FakePlaybackController();
  final router = GoRouter(
    initialLocation: '/home/recordings',
    routes: [
      GoRoute(
        path: '/home/recordings',
        builder: (context, state) => const RecordingLibraryScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const Text('home')),
      GoRoute(
        path: '/home/recordings/:slotId/artwork',
        builder: (context, state) => const Text('artwork'),
      ),
    ],
  );
  addTearDown(router.dispose);

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
        recordingPlaybackControllerProvider(
          RecordingPlaybackSurface.library,
        ).overrideWith(() => playbackController),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(RecordingLibraryScreen)),
  );

  return _LibraryHarness(
    router: router,
    container: container,
    playbackController: playbackController,
  );
}

class _LibraryHarness {
  const _LibraryHarness({
    required this.router,
    required this.container,
    required this.playbackController,
  });

  final GoRouter router;
  final ProviderContainer container;
  final _FakePlaybackController playbackController;
}

class _FakePlaybackController extends RecordingPlaybackController {
  String? toggledTargetKey;

  @override
  RecordingPlaybackState build() => const RecordingPlaybackState.idle();

  @override
  Future<void> toggle(RecordingPlaybackTarget target) async {
    toggledTargetKey = target.key;
    state = RecordingPlaybackState(
      activeTargetKey: target.key,
      isPlaying: true,
      isBusy: false,
    );
  }

  @override
  Future<void> syncAvailableTargetKeys(Set<String> targetKeys) async {}
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

CurrentCoupleRecording _currentRecording() {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CurrentCoupleRecording(
    recordingId: 'current-recording',
    senderUserId: 'user-id',
    durationMs: 2000,
    recordedAt: timestamp,
    revision: 1,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/current.m4a',
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
