import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_widget_asset_downloader.dart';
import '../data/home_widget_platform_store.dart';
import '../data/home_widget_snapshot_repository.dart';
import 'home_widget_synchronizer.dart';

final homeWidgetSynchronizerProvider = Provider<HomeWidgetSynchronizer>((ref) {
  return HomeWidgetSynchronizer(
    store: ref.watch(homeWidgetStoreProvider),
    downloader: ref.watch(homeWidgetAssetDownloaderProvider),
  );
});

final homeWidgetSyncServiceProvider = Provider<HomeWidgetSyncService>((ref) {
  return HomeWidgetSyncService(
    snapshotRepository: ref.watch(homeWidgetSnapshotRepositoryProvider),
    synchronizer: ref.watch(homeWidgetSynchronizerProvider),
  );
});

class HomeWidgetSyncService {
  const HomeWidgetSyncService({
    required HomeWidgetSnapshotRepository snapshotRepository,
    required HomeWidgetSynchronizer synchronizer,
  }) : _snapshotRepository = snapshotRepository,
       _synchronizer = synchronizer;

  final HomeWidgetSnapshotRepository _snapshotRepository;
  final HomeWidgetSynchronizer _synchronizer;

  Future<void> synchronize() async {
    if (!Platform.isAndroid) {
      return;
    }

    final snapshot = await _snapshotRepository.fetchSnapshot();
    await _synchronizer.synchronize(snapshot);
  }

  Future<void> synchronizeSafely() async {
    try {
      await synchronize();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[widget] synchronization failed: $error');
      }
    }
  }
}
