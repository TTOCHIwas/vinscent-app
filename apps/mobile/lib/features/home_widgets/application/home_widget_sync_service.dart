import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_widget_asset_downloader.dart';
import '../data/home_widget_platform_store.dart';
import '../data/home_widget_recording_cache_repository.dart';
import '../data/home_widget_recording_snapshot_repository.dart';
import '../data/home_widget_snapshot_repository.dart';
import 'home_widget_synchronizer.dart';

final homeWidgetRecordingCacheRepositoryProvider =
    Provider<HomeWidgetRecordingCacheRepository>((ref) {
      return HomeWidgetRecordingCacheRepository(
        store: ref.watch(homeWidgetStoreProvider),
      );
    });

final homeWidgetSynchronizerProvider = Provider<HomeWidgetSynchronizer>((ref) {
  return HomeWidgetSynchronizer(
    store: ref.watch(homeWidgetStoreProvider),
    downloader: ref.watch(homeWidgetAssetDownloaderProvider),
    recordingCacheRepository: ref.watch(
      homeWidgetRecordingCacheRepositoryProvider,
    ),
  );
});

final homeWidgetSyncServiceProvider = Provider<HomeWidgetSyncService>((ref) {
  return HomeWidgetSyncService(
    snapshotRepository: ref.watch(homeWidgetSnapshotRepositoryProvider),
    synchronizer: ref.watch(homeWidgetSynchronizerProvider),
  );
});

final homeWidgetRecordingSyncServiceProvider =
    Provider<HomeWidgetRecordingSyncService>((ref) {
      return HomeWidgetRecordingSyncService(
        snapshotRepository: ref.watch(
          homeWidgetRecordingSnapshotRepositoryProvider,
        ),
        synchronizer: ref.watch(homeWidgetSynchronizerProvider),
      );
    });

class HomeWidgetSyncService {
  HomeWidgetSyncService({
    required HomeWidgetSnapshotRepository snapshotRepository,
    required HomeWidgetSynchronizer synchronizer,
    this.maxAttempts = 2,
    this.retryDelay = const Duration(milliseconds: 750),
    bool? isSupportedPlatform,
  }) : _snapshotRepository = snapshotRepository,
       _synchronizer = synchronizer,
       _isSupportedPlatform =
           isSupportedPlatform ?? (Platform.isAndroid || Platform.isIOS),
       assert(maxAttempts > 0);

  final HomeWidgetSnapshotRepository _snapshotRepository;
  final HomeWidgetSynchronizer _synchronizer;
  final bool _isSupportedPlatform;
  final int maxAttempts;
  final Duration retryDelay;

  Future<void> synchronize() async {
    if (!_isSupportedPlatform) {
      return;
    }

    final recordingReadFence = await _synchronizer.captureRecordingReadFence();
    final snapshot = await _snapshotRepository.fetchSnapshot();
    await _synchronizer.synchronize(
      snapshot,
      recordingReadFence: recordingReadFence,
    );
    if (snapshot?.requiresRetry ?? false) {
      throw const HomeWidgetSnapshotIncompleteException();
    }
  }

  Future<void> synchronizeSafely() async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await synchronize();
        return;
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[widget] synchronization attempt $attempt/$maxAttempts failed: '
            '$error',
          );
        }
        if (attempt < maxAttempts) {
          await Future<void>.delayed(retryDelay);
        }
      }
    }
  }
}

class HomeWidgetSnapshotIncompleteException implements Exception {
  const HomeWidgetSnapshotIncompleteException();

  @override
  String toString() => 'Home widget snapshot contains deferred assets';
}

class HomeWidgetRecordingSyncService {
  HomeWidgetRecordingSyncService({
    required HomeWidgetRecordingSnapshotRepository snapshotRepository,
    required HomeWidgetSynchronizer synchronizer,
    this.maxAttempts = 2,
    this.retryDelay = const Duration(milliseconds: 750),
    bool? isSupportedPlatform,
  }) : _snapshotRepository = snapshotRepository,
       _synchronizer = synchronizer,
       _isSupportedPlatform =
           isSupportedPlatform ?? (Platform.isAndroid || Platform.isIOS),
       assert(maxAttempts > 0);

  final HomeWidgetRecordingSnapshotRepository _snapshotRepository;
  final HomeWidgetSynchronizer _synchronizer;
  final bool _isSupportedPlatform;
  final int maxAttempts;
  final Duration retryDelay;

  Future<void> synchronize({required String expectedCoupleId}) async {
    if (!_isSupportedPlatform) {
      return;
    }

    final recordingReadFence = await _synchronizer.captureRecordingReadFence();
    final update = await _snapshotRepository.fetchRecordingAudio(
      expectedCoupleId: expectedCoupleId,
    );
    await _synchronizer.synchronizeRecording(
      update,
      recordingReadFence: recordingReadFence,
    );
    if (update.shouldPreserve) {
      throw const HomeWidgetSnapshotIncompleteException();
    }
  }

  Future<bool> synchronizeSafely({required String expectedCoupleId}) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await synchronize(expectedCoupleId: expectedCoupleId);
        return true;
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[widget] recording synchronization attempt '
            '$attempt/$maxAttempts failed: $error',
          );
        }
        if (attempt < maxAttempts) {
          await Future<void>.delayed(retryDelay);
        }
      }
    }
    return false;
  }
}
