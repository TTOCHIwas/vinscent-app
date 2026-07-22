import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_data_gateways.dart';
import 'package:vinscent/features/recordings/data/supabase_couple_recording_repository.dart';

void main() {
  test('forwards overview reads and current recording uploads', () async {
    const expectedOverview = CoupleRecordingOverview(
      slotLimit: 3,
      currentRecording: null,
      savedSlots: [],
    );
    final overviewReader = _FakeOverviewReader(expectedOverview);
    final currentRecordingWriter = _FakeCurrentRecordingWriter();
    final repository = _buildRepository(
      overviewReader: overviewReader,
      currentRecordingWriter: currentRecordingWriter,
    );
    final audioBytes = Uint8List.fromList([1, 2, 3]);

    expect(await repository.fetchOverview(), same(expectedOverview));
    await repository.uploadCurrentRecording(
      coupleId: 'couple-id',
      audioBytes: audioBytes,
      durationMs: 1200,
      recordingId: 'recording-id',
      resumeExistingUpload: true,
    );

    expect(overviewReader.fetchCount, 1);
    expect(currentRecordingWriter.coupleId, 'couple-id');
    expect(currentRecordingWriter.audioBytes, same(audioBytes));
    expect(currentRecordingWriter.durationMs, 1200);
    expect(currentRecordingWriter.recordingId, 'recording-id');
    expect(currentRecordingWriter.resumeExistingUpload, isTrue);
  });

  test('forwards slot lifecycle operations and results', () async {
    const saveResult = CoupleRecordingSlotSaveResult(
      slotId: 'slot-id',
      slotIndex: 2,
      slotRevision: 4,
    );
    final slotWriter = _FakeSlotWriter(saveResult);
    final repository = _buildRepository(slotWriter: slotWriter);

    final result = await repository.saveCurrentRecordingToSlot(
      slotIndex: 2,
      title: 'title',
      expectedSlotRevision: 3,
    );
    await repository.deleteSlot(slotId: 'slot-id', expectedSlotRevision: 4);
    await repository.openNextSlot();

    expect(result, same(saveResult));
    expect(slotWriter.savedSlotIndex, 2);
    expect(slotWriter.savedTitle, 'title');
    expect(slotWriter.savedExpectedRevision, 3);
    expect(slotWriter.deletedSlotId, 'slot-id');
    expect(slotWriter.deletedExpectedRevision, 4);
    expect(slotWriter.openCount, 1);
  });

  test('forwards artwork and placement operations', () async {
    final artworkStore = _FakeArtworkStore();
    final placementStore = _FakePlacementStore();
    final repository = _buildRepository(
      artworkStore: artworkStore,
      placementStore: placementStore,
    );
    final previewBytes = Uint8List.fromList([1, 2]);
    final drawingDataBytes = Uint8List.fromList([3, 4]);

    expect(
      await repository.fetchSlotArtworkDrawingData(
        drawingDataPath: 'artwork/data.gz',
      ),
      [9, 8, 7],
    );
    await repository.saveSlotArtwork(
      coupleId: 'couple-id',
      slotId: 'slot-id',
      expectedSlotRevision: 5,
      previewBytes: previewBytes,
      drawingDataBytes: drawingDataBytes,
    );
    await repository.upsertSlotPlacement(
      slotId: 'slot-id',
      normalizedX: 0.25,
      normalizedY: 0.75,
      expectedPlacementRevision: 6,
    );
    await repository.deleteSlotPlacement(
      slotId: 'slot-id',
      expectedPlacementRevision: 7,
    );

    expect(artworkStore.fetchedPath, 'artwork/data.gz');
    expect(artworkStore.coupleId, 'couple-id');
    expect(artworkStore.slotId, 'slot-id');
    expect(artworkStore.expectedSlotRevision, 5);
    expect(artworkStore.previewBytes, same(previewBytes));
    expect(artworkStore.drawingDataBytes, same(drawingDataBytes));
    expect(placementStore.upsertedSlotId, 'slot-id');
    expect(placementStore.normalizedX, 0.25);
    expect(placementStore.normalizedY, 0.75);
    expect(placementStore.upsertedExpectedRevision, 6);
    expect(placementStore.deletedSlotId, 'slot-id');
    expect(placementStore.deletedExpectedRevision, 7);
  });
}

SupabaseCoupleRecordingRepository _buildRepository({
  CoupleRecordingOverviewReader? overviewReader,
  CurrentCoupleRecordingWriter? currentRecordingWriter,
  CoupleRecordingSlotWriter? slotWriter,
  CoupleRecordingSlotArtworkStore? artworkStore,
  CoupleRecordingSlotPlacementStore? placementStore,
}) {
  return SupabaseCoupleRecordingRepository(
    overviewReader:
        overviewReader ??
        _FakeOverviewReader(
          const CoupleRecordingOverview(
            slotLimit: 0,
            currentRecording: null,
            savedSlots: [],
          ),
        ),
    currentRecordingWriter:
        currentRecordingWriter ?? _FakeCurrentRecordingWriter(),
    slotWriter:
        slotWriter ??
        _FakeSlotWriter(
          const CoupleRecordingSlotSaveResult(
            slotId: 'unused',
            slotIndex: 1,
            slotRevision: 1,
          ),
        ),
    artworkStore: artworkStore ?? _FakeArtworkStore(),
    placementStore: placementStore ?? _FakePlacementStore(),
  );
}

class _FakeOverviewReader implements CoupleRecordingOverviewReader {
  _FakeOverviewReader(this.overview);

  final CoupleRecordingOverview overview;
  int fetchCount = 0;

  @override
  Future<CoupleRecordingOverview> fetchOverview() async {
    fetchCount += 1;
    return overview;
  }
}

class _FakeCurrentRecordingWriter implements CurrentCoupleRecordingWriter {
  String? coupleId;
  Uint8List? audioBytes;
  int? durationMs;
  String? recordingId;
  bool? resumeExistingUpload;

  @override
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
    String? recordingId,
    bool resumeExistingUpload = false,
  }) async {
    this.coupleId = coupleId;
    this.audioBytes = audioBytes;
    this.durationMs = durationMs;
    this.recordingId = recordingId;
    this.resumeExistingUpload = resumeExistingUpload;
  }
}

class _FakeSlotWriter implements CoupleRecordingSlotWriter {
  _FakeSlotWriter(this.result);

  final CoupleRecordingSlotSaveResult result;
  int? savedSlotIndex;
  String? savedTitle;
  int? savedExpectedRevision;
  String? deletedSlotId;
  int? deletedExpectedRevision;
  int openCount = 0;

  @override
  Future<CoupleRecordingSlotSaveResult> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {
    savedSlotIndex = slotIndex;
    savedTitle = title;
    savedExpectedRevision = expectedSlotRevision;
    return result;
  }

  @override
  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) async {
    deletedSlotId = slotId;
    deletedExpectedRevision = expectedSlotRevision;
  }

  @override
  Future<void> openNextSlot() async {
    openCount += 1;
  }
}

class _FakeArtworkStore implements CoupleRecordingSlotArtworkStore {
  String? fetchedPath;
  String? coupleId;
  String? slotId;
  int? expectedSlotRevision;
  Uint8List? previewBytes;
  Uint8List? drawingDataBytes;

  @override
  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  }) async {
    fetchedPath = drawingDataPath;
    return Uint8List.fromList([9, 8, 7]);
  }

  @override
  Future<void> saveSlotArtwork({
    required String coupleId,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) async {
    this.coupleId = coupleId;
    this.slotId = slotId;
    this.expectedSlotRevision = expectedSlotRevision;
    this.previewBytes = previewBytes;
    this.drawingDataBytes = drawingDataBytes;
  }
}

class _FakePlacementStore implements CoupleRecordingSlotPlacementStore {
  String? upsertedSlotId;
  double? normalizedX;
  double? normalizedY;
  int? upsertedExpectedRevision;
  String? deletedSlotId;
  int? deletedExpectedRevision;

  @override
  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) async {
    upsertedSlotId = slotId;
    this.normalizedX = normalizedX;
    this.normalizedY = normalizedY;
    upsertedExpectedRevision = expectedPlacementRevision;
  }

  @override
  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  }) async {
    deletedSlotId = slotId;
    deletedExpectedRevision = expectedPlacementRevision;
  }
}
