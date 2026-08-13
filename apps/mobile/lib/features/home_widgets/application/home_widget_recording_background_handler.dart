import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import '../../couple/data/couple_repository.dart';
import '../../notifications/data/android_push_notification_presenter.dart';
import '../../recordings/data/couple_recording_repository.dart';
import '../data/home_widget_asset_downloader.dart';
import '../data/home_widget_platform_store.dart';
import '../data/home_widget_recording_cache_repository.dart';
import '../data/home_widget_recording_snapshot_repository.dart';
import 'home_widget_recording_notification_coordinator.dart';
import 'home_widget_sync_service.dart';
import 'home_widget_synchronizer.dart';

@pragma('vm:entry-point')
Future<void> handleHomeWidgetRecordingBackgroundMessage(
  RemoteMessage message,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.android &&
      message.notification == null) {
    try {
      final presenter = AndroidPushNotificationPresenter(
        localNotifications: FlutterLocalNotificationsPlugin(),
      );
      await presenter.configure();
      await presenter.show(message);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[push] background notification display failed: $error');
      }
    }
  }

  final notification = HomeWidgetRecordingNotification.tryParse(message.data);
  if (notification == null) {
    return;
  }

  try {
    await AppBootstrap.initializeBackgroundServices();
    await configureHomeWidgetPlatform();

    const store = PluginHomeWidgetStore();
    final cacheRepository = HomeWidgetRecordingCacheRepository(store: store);
    final synchronizer = HomeWidgetSynchronizer(
      store: store,
      downloader: const HttpHomeWidgetAssetDownloader(),
      recordingCacheRepository: cacheRepository,
    );
    final syncService = HomeWidgetRecordingSyncService(
      snapshotRepository: SupabaseHomeWidgetRecordingSnapshotRepository(
        coupleRepository: const SupabaseCoupleRepository(),
        recordingRepository: const SupabaseCoupleRecordingRepository(),
      ),
      synchronizer: synchronizer,
      maxAttempts: 1,
    );
    final coordinator = HomeWidgetRecordingNotificationCoordinator(
      markRequired: ({required coupleId, required recordingId}) async {
        await cacheRepository.markRequired(
          coupleId: coupleId,
          recordingId: recordingId,
        );
      },
      synchronizeRecording: ({required expectedCoupleId}) {
        return syncService.synchronizeSafely(
          expectedCoupleId: expectedCoupleId,
        );
      },
    );
    await coordinator.handleSafely(message.data);
  } catch (error) {
    if (kDebugMode) {
      debugPrint('[widget] background recording sync failed: $error');
    }
  }
}
