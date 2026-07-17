import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/recordings/application/couple_recording_overview_controller.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_overview_change_source.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test(
    'coalesces a burst of shared recording changes into one refresh',
    () async {
      final repository = _FakeRecordingRepository();
      final changeSource = _FakeOverviewChangeSource();
      final container = _buildContainer(
        repository: repository,
        changeSource: changeSource,
      );
      addTearDown(container.dispose);

      await container.read(coupleRecordingOverviewControllerProvider.future);
      expect(repository.fetchCount, 1);
      expect(changeSource.watchedCoupleId, 'couple-id');

      changeSource.emit();
      changeSource.emit();
      changeSource.emit();

      await _waitUntil(() => repository.fetchCount == 2);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(repository.fetchCount, 2);
    },
  );

  test('keeps current overview visible during a realtime refresh', () async {
    final repository = _FakeRecordingRepository();
    final changeSource = _FakeOverviewChangeSource();
    final container = _buildContainer(
      repository: repository,
      changeSource: changeSource,
    );
    addTearDown(container.dispose);

    await container.read(coupleRecordingOverviewControllerProvider.future);
    final refreshBarrier = Completer<void>();
    repository.fetchBarrier = refreshBarrier;

    changeSource.emit();
    await _waitUntil(() => repository.fetchCount == 2);

    expect(
      container.read(coupleRecordingOverviewControllerProvider),
      isA<AsyncData<CoupleRecordingOverview?>>(),
    );

    refreshBarrier.complete();
    await _waitUntil(() => repository.completedFetchCount == 2);
  });

  test('replaces and disposes the realtime subscription on rebuild', () async {
    final repository = _FakeRecordingRepository();
    final changeSource = _FakeOverviewChangeSource();
    final container = _buildContainer(
      repository: repository,
      changeSource: changeSource,
    );

    await container.read(coupleRecordingOverviewControllerProvider.future);
    container.invalidate(coupleRecordingOverviewControllerProvider);
    await container.read(coupleRecordingOverviewControllerProvider.future);

    expect(changeSource.watchCount, 2);
    expect(changeSource.cancelCount, 1);

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(changeSource.cancelCount, 2);
  });

  test(
    'queues one follow-up refresh instead of fetching concurrently',
    () async {
      final repository = _FakeRecordingRepository();
      final changeSource = _FakeOverviewChangeSource();
      final container = _buildContainer(
        repository: repository,
        changeSource: changeSource,
      );
      addTearDown(container.dispose);

      await container.read(coupleRecordingOverviewControllerProvider.future);
      final refreshBarrier = Completer<void>();
      repository.fetchBarrier = refreshBarrier;

      changeSource.emit();
      await _waitUntil(() => repository.fetchCount == 2);
      changeSource.emit();
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(repository.fetchCount, 2);
      expect(repository.maxConcurrentFetchCount, 1);

      repository.fetchBarrier = null;
      refreshBarrier.complete();
      await _waitUntil(() => repository.fetchCount == 3);

      expect(repository.maxConcurrentFetchCount, 1);
    },
  );
}

ProviderContainer _buildContainer({
  required _FakeRecordingRepository repository,
  required _FakeOverviewChangeSource changeSource,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWithBuild(
        (ref, notifier) => AuthStatus.authenticated,
      ),
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => activeCouple(),
      ),
      coupleRecordingRepositoryProvider.overrideWithValue(repository),
      coupleRecordingOverviewChangeSourceProvider.overrideWithValue(
        changeSource,
      ),
    ],
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(timeoutAt)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

class _FakeOverviewChangeSource implements CoupleRecordingOverviewChangeSource {
  final List<StreamController<void>> _controllers = [];
  String? watchedCoupleId;
  int watchCount = 0;
  int cancelCount = 0;

  void emit() {
    _controllers.last.add(null);
  }

  @override
  Stream<void> watch({required String coupleId}) {
    watchedCoupleId = coupleId;
    watchCount += 1;
    final controller = StreamController<void>(
      onCancel: () {
        cancelCount += 1;
      },
    );
    _controllers.add(controller);
    return controller.stream;
  }
}

class _FakeRecordingRepository implements CoupleRecordingRepository {
  int fetchCount = 0;
  int completedFetchCount = 0;
  int activeFetchCount = 0;
  int maxConcurrentFetchCount = 0;
  Completer<void>? fetchBarrier;

  @override
  Future<CoupleRecordingOverview> fetchOverview() async {
    fetchCount += 1;
    activeFetchCount += 1;
    if (activeFetchCount > maxConcurrentFetchCount) {
      maxConcurrentFetchCount = activeFetchCount;
    }
    final barrier = fetchBarrier;
    try {
      await barrier?.future;
      completedFetchCount += 1;
      return const CoupleRecordingOverview(
        slotLimit: 0,
        currentRecording: null,
        savedSlots: [],
      );
    } finally {
      activeFetchCount -= 1;
    }
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
