import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/recordings/application/couple_recording_overview_controller.dart';
import 'package:vinscent/features/recordings/application/recording_playback_controller.dart';
import 'package:vinscent/features/recordings/application/recording_slot_placement_session.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';
import 'package:vinscent/features/recordings/presentation/recording_library_screen.dart';
import 'package:vinscent/features/safety/data/safety_report.dart';
import 'package:vinscent/features/safety/data/safety_report_repository.dart';

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

  testWidgets('slot actions open in a bottom sheet and keep existing routing', (
    tester,
  ) async {
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

    expect(
      find.byKey(const ValueKey('recording-library-slot-action-sheet-slot-1')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('그림 수정'), findsOneWidget);
    expect(find.text('홈에 배치'), findsOneWidget);
    expect(find.text('현재 녹음으로 교체'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('recording-library-slot-action-artwork-slot-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('artwork'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('reports the partner current recording', (tester) async {
    final safetyRepository = _FakeSafetyReportRepository();
    final overview = CoupleRecordingOverview(
      slotLimit: 0,
      currentRecording: _currentRecording(senderUserId: 'partner-id'),
      savedSlots: const [],
    );
    await _pumpLibrary(
      tester,
      overview: overview,
      safetyReportRepository: safetyRepository,
    );

    await tester.tap(
      find.byKey(const Key('recording-library-current-report')),
    );
    await tester.pumpAndSettle();
    await _submitReport(tester);

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.recording,
        id: 'current-recording',
      ),
    );
  });

  testWidgets('reports a slot last edited by the partner', (tester) async {
    final safetyRepository = _FakeSafetyReportRepository();
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: null,
      savedSlots: [
        _slot(
          senderUserId: 'partner-id',
          updatedByUserId: 'partner-id',
        ),
      ],
    );
    await _pumpLibrary(
      tester,
      overview: overview,
      safetyReportRepository: safetyRepository,
    );

    await tester.tap(
      find.byKey(const ValueKey('recording-library-slot-menu-slot-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('recording-library-slot-action-report-slot-1'),
      ),
    );
    await tester.pumpAndSettle();
    await _submitReport(tester);

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.recording,
        id: 'slot-1',
      ),
    );
  });

  testWidgets('reports partner audio when I last edited its slot', (
    tester,
  ) async {
    final safetyRepository = _FakeSafetyReportRepository();
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: null,
      savedSlots: [
        _slot(
          senderUserId: 'partner-id',
          updatedByUserId: _profile.id,
        ),
      ],
    );
    await _pumpLibrary(
      tester,
      overview: overview,
      safetyReportRepository: safetyRepository,
    );

    await tester.tap(
      find.byKey(const ValueKey('recording-library-slot-menu-slot-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('recording-library-slot-action-report-slot-1'),
      ),
    );
    await tester.pumpAndSettle();
    await _submitReport(tester);

    expect(
      safetyRepository.requests.single.target,
      const SafetyReportTarget(
        type: SafetyReportTargetType.recording,
        id: 'recording-1',
      ),
    );
  });

  testWidgets('slot title save uses the shared check action', (tester) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: _currentRecording(),
      savedSlots: [_slot()],
    );
    await _pumpLibrary(tester, overview: overview);

    await tester.tap(
      find.byKey(const ValueKey('recording-library-slot-menu-slot-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('recording-library-slot-action-replace-slot-1'),
      ),
    );
    await tester.pumpAndSettle();

    final saveAction = find.byKey(
      const ValueKey('recording-library-slot-title-save'),
    );
    expect(saveAction, findsOneWidget);
    expect(
      find.descendant(
        of: saveAction,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('저장'), findsOneWidget);
  });

  testWidgets('slot actions use one restrained line icon hierarchy', (
    tester,
  ) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: _currentRecording(),
      savedSlots: [_slot()],
    );
    await _pumpLibrary(tester, overview: overview);

    await tester.tap(
      find.byKey(const ValueKey('recording-library-slot-menu-slot-1')),
    );
    await tester.pumpAndSettle();

    final regularActions = ['artwork', 'homePlacement', 'replace'];
    for (final action in regularActions) {
      final row = find.byKey(
        ValueKey('recording-library-slot-action-$action-slot-1'),
      );
      final icon = tester.widget<Icon>(
        find.descendant(of: row, matching: find.byType(Icon)),
      );
      final label = tester.widget<Text>(
        find.descendant(of: row, matching: find.byType(Text)),
      );

      expect(icon.icon?.fontFamily, isNot('MaterialIcons'));
      expect(icon.color, AppColors.textMuted);
      expect(label.style?.fontWeight, FontWeight.w400);
      expect(label.style?.color, AppColors.textPrimary);
    }

    final deleteRow = find.byKey(
      const ValueKey('recording-library-slot-action-delete-slot-1'),
    );
    final deleteIcon = tester.widget<Icon>(
      find.descendant(of: deleteRow, matching: find.byType(Icon)),
    );
    final deleteLabel = tester.widget<Text>(
      find.descendant(of: deleteRow, matching: find.byType(Text)),
    );
    final errorColor = Theme.of(tester.element(deleteRow)).colorScheme.error;

    expect(deleteIcon.icon?.fontFamily, isNot('MaterialIcons'));
    expect(deleteIcon.color, errorColor);
    expect(deleteLabel.style?.fontWeight, FontWeight.w400);
    expect(deleteLabel.style?.color, errorColor);
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

  testWidgets('an empty slot opens the combined title and artwork editor', (
    tester,
  ) async {
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
    expect(
      find.descendant(
        of: addButton,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('create-slot'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a read-only library exposes artwork viewing only', (
    tester,
  ) async {
    final overview = CoupleRecordingOverview(
      slotLimit: 1,
      currentRecording: _currentRecording(),
      savedSlots: [_slot()],
    );
    await _pumpLibrary(
      tester,
      overview: overview,
      couple: archivedReadOnlyCouple(),
    );

    await tester.tap(
      find.byKey(const ValueKey('recording-library-slot-menu-slot-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('그림 보기'), findsOneWidget);
    expect(find.text('홈에 배치'), findsNothing);
    expect(find.text('현재 녹음으로 교체'), findsNothing);
    expect(find.text('삭제'), findsNothing);
  });
}

Future<_LibraryHarness> _pumpLibrary(
  WidgetTester tester, {
  required CoupleRecordingOverview overview,
  Couple? couple,
  SafetyReportRepository? safetyReportRepository,
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
      GoRoute(
        path: '/home/recordings/create/:slotIndex',
        builder: (context, state) => const Text('create-slot'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => couple ?? activeCouple(),
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
        if (safetyReportRepository != null)
          safetyReportRepositoryProvider.overrideWithValue(
            safetyReportRepository,
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

  return _LibraryHarness(
    router: router,
    container: container,
    playbackController: playbackController,
  );
}

Future<void> _submitReport(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('safety-report-reason-inappropriate')),
  );
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('safety-report-submit')));
  await tester.tap(find.byKey(const Key('safety-report-submit')));
  await tester.pumpAndSettle();
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

class _FakeSafetyReportRepository implements SafetyReportRepository {
  final requests = <SafetyReportRequest>[];

  @override
  Future<void> submit(SafetyReportRequest request) async {
    requests.add(request);
  }
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
  Future<CoupleRecordingSlotSaveResult> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async => CoupleRecordingSlotSaveResult(
    slotId: 'slot-$slotIndex',
    slotIndex: slotIndex,
    slotRevision: expectedSlotRevision ?? 1,
  );

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

CoupleRecordingSlot _slot({
  String senderUserId = 'user-id',
  String? updatedByUserId = 'user-id',
}) {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CoupleRecordingSlot(
    slotId: 'slot-1',
    slotIndex: 1,
    title: '첫 녹음',
    recordingId: 'recording-1',
    senderUserId: senderUserId,
    durationMs: 1000,
    recordedAt: timestamp,
    slotRevision: 1,
    createdByUserId: 'user-id',
    updatedByUserId: updatedByUserId,
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

CurrentCoupleRecording _currentRecording({String senderUserId = 'user-id'}) {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CurrentCoupleRecording(
    recordingId: 'current-recording',
    senderUserId: senderUserId,
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
