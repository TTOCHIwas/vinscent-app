import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../couple/data/couple_repository.dart';
import '../../recordings/data/couple_recording_repository.dart';
import 'home_widget_snapshot.dart';

final homeWidgetRecordingSnapshotRepositoryProvider =
    Provider<HomeWidgetRecordingSnapshotRepository>((ref) {
      return SupabaseHomeWidgetRecordingSnapshotRepository(
        coupleRepository: ref.watch(coupleRepositoryProvider),
        recordingRepository: ref.watch(coupleRecordingRepositoryProvider),
      );
    });

abstract interface class HomeWidgetRecordingSnapshotRepository {
  Future<HomeWidgetAssetUpdate> fetchRecordingAudio({
    required String expectedCoupleId,
  });
}

class SupabaseHomeWidgetRecordingSnapshotRepository
    implements HomeWidgetRecordingSnapshotRepository {
  SupabaseHomeWidgetRecordingSnapshotRepository({
    required CoupleRepository coupleRepository,
    required CoupleRecordingRepository recordingRepository,
  }) : _coupleRepository = coupleRepository,
       _assetLoader = HomeWidgetRecordingAssetLoader(
         recordingRepository: recordingRepository,
       );

  final CoupleRepository _coupleRepository;
  final HomeWidgetRecordingAssetLoader _assetLoader;

  @override
  Future<HomeWidgetAssetUpdate> fetchRecordingAudio({
    required String expectedCoupleId,
  }) async {
    if (!AppConfig.isSupabaseConfigured ||
        Supabase.instance.client.auth.currentUser == null) {
      return const HomeWidgetAssetUpdate.preserve();
    }

    final couple = await _coupleRepository.fetchCurrentCouple();
    if (couple == null || !couple.canReadSharedData) {
      return const HomeWidgetAssetUpdate.remove();
    }
    if (couple.id != expectedCoupleId) {
      return const HomeWidgetAssetUpdate.preserve();
    }
    return _assetLoader.fetch(coupleId: couple.id);
  }
}

class HomeWidgetRecordingAssetLoader {
  const HomeWidgetRecordingAssetLoader({
    required CoupleRecordingRepository recordingRepository,
  }) : _recordingRepository = recordingRepository;

  static const _maximumAudioBytes = 4 * 1024 * 1024;

  final CoupleRecordingRepository _recordingRepository;

  Future<HomeWidgetAssetUpdate> fetch({required String coupleId}) async {
    try {
      final recording =
          (await _recordingRepository.fetchOverview()).currentRecording;
      if (recording == null) {
        return const HomeWidgetAssetUpdate.remove();
      }

      return HomeWidgetAssetUpdate.replace(
        HomeWidgetRecordingRemoteAsset(
          url: recording.audioUrl,
          coupleId: coupleId,
          recordingId: recording.recordingId,
          revision: recording.revision,
          maxBytes: _maximumAudioBytes,
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[widget] recording snapshot fetch failed: $error');
      }
      return const HomeWidgetAssetUpdate.preserve();
    }
  }
}
