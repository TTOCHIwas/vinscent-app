import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date/today_controller.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_status.dart';
import '../features/couple/application/couple_controller.dart';
import '../features/characters/application/couple_character_controller.dart';
import '../features/home_widgets/application/home_widget_launch_coordinator.dart';
import '../features/home_widgets/application/home_widget_launch_policy.dart';
import '../features/home_widgets/application/home_widget_sync_scheduler.dart';
import '../features/home_widgets/application/home_widget_sync_service.dart';
import '../features/home_widgets/data/home_widget_platform_store.dart';
import '../features/notifications/application/push_token_controller.dart';
import '../features/notifications/application/push_notification_route.dart';
import '../features/notifications/data/push_token_repository.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/recordings/application/couple_recording_overview_controller.dart';
import '../features/story_loops/application/today_story_loop_summary_provider.dart';
import 'router.dart';

class VinscentApp extends ConsumerStatefulWidget {
  const VinscentApp({super.key});

  @override
  ConsumerState<VinscentApp> createState() => _VinscentAppState();
}

class _VinscentAppState extends ConsumerState<VinscentApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationOpenSubscription;
  late final HomeWidgetSyncScheduler _widgetSyncScheduler;
  Uri? _pendingWidgetUri;
  String? _pendingNotificationLocation;
  bool _isHandlingWidgetLaunch = false;
  bool _isHandlingNotificationLaunch = false;

  @override
  void initState() {
    super.initState();
    _widgetSyncScheduler = HomeWidgetSyncScheduler(
      synchronize: () =>
          ref.read(homeWidgetSyncServiceProvider).synchronizeSafely(),
    );
    WidgetsBinding.instance.addObserver(this);
    if (_supportsPushNotifications) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeNotificationLaunches());
      });
    }
    if (_supportsHomeWidgets) {
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((_) {
        _scheduleWidgetSync();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeHomeWidgets());
      });
    }
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _notificationOpenSubscription?.cancel();
    _widgetSyncScheduler.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeNotificationLaunches() async {
    final repository = ref.read(pushTokenRepositoryProvider);
    _notificationOpenSubscription = repository.notificationOpens.listen(
      _queueNotificationLaunch,
    );

    try {
      final initialData = await repository.initiallyOpenedNotification();
      if (initialData != null) {
        _queueNotificationLaunch(initialData);
      }
    } catch (error) {
      debugPrint('[push] Initial notification launch failed: $error');
    }
  }

  void _queueNotificationLaunch(Map<String, dynamic> data) {
    final location = resolvePushNotificationLocation(data);
    if (location == null) {
      return;
    }

    _pendingNotificationLocation = location;
    unawaited(_drainNotificationLaunch());
  }

  Future<void> _drainNotificationLaunch() async {
    if (_isHandlingNotificationLaunch ||
        _pendingNotificationLocation == null ||
        ref.read(authControllerProvider) != AuthStatus.authenticated ||
        !ref.read(profileControllerProvider).hasValue ||
        !ref.read(coupleControllerProvider).hasValue) {
      return;
    }

    _isHandlingNotificationLaunch = true;
    final location = _pendingNotificationLocation;
    try {
      if (_pendingNotificationLocation == location) {
        _pendingNotificationLocation = null;
      }
      ref.read(appRouterProvider).go(location!);
    } finally {
      _isHandlingNotificationLaunch = false;
      if (_pendingNotificationLocation != null &&
          _pendingNotificationLocation != location &&
          mounted) {
        unawaited(_drainNotificationLaunch());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayControllerProvider.notifier).refresh();
      ref.invalidate(coupleControllerProvider);
      _scheduleWidgetSync();
    }
  }

  void _queueWidgetLaunch(Uri? uri) {
    if (HomeWidgetLaunchAction.fromUri(uri) == null) {
      return;
    }
    _pendingWidgetUri = uri;
    unawaited(_drainWidgetLaunch());
  }

  Future<void> _initializeHomeWidgets() async {
    await configureHomeWidgetPlatform();
    if (!mounted) {
      return;
    }

    final coordinator = ref.read(homeWidgetLaunchCoordinatorProvider);
    _widgetClickSubscription = coordinator.widgetClicks.listen(
      _queueWidgetLaunch,
    );
    _queueWidgetLaunch(await coordinator.initiallyLaunchedFromWidget());
    _scheduleWidgetSync();
  }

  Future<void> _drainWidgetLaunch() async {
    if (_isHandlingWidgetLaunch ||
        _pendingWidgetUri == null ||
        ref.read(authControllerProvider) != AuthStatus.authenticated) {
      return;
    }

    _isHandlingWidgetLaunch = true;
    final uri = _pendingWidgetUri;
    try {
      final target = await ref
          .read(homeWidgetLaunchCoordinatorProvider)
          .resolveTarget(uri);
      if (!mounted || target == null) {
        return;
      }
      if (_pendingWidgetUri == uri) {
        _pendingWidgetUri = null;
      }
      ref.read(appRouterProvider).go(target);
    } finally {
      _isHandlingWidgetLaunch = false;
      if (_pendingWidgetUri != null && _pendingWidgetUri != uri && mounted) {
        unawaited(_drainWidgetLaunch());
      }
    }
  }

  void _scheduleWidgetSync() {
    if (!_supportsHomeWidgets) {
      return;
    }
    _widgetSyncScheduler.schedule();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.watch(pushTokenControllerProvider);
    if (_supportsHomeWidgets) {
      ref.listen(authControllerProvider, (_, next) {
        if (next == AuthStatus.authenticated) {
          unawaited(_drainWidgetLaunch());
          unawaited(_drainNotificationLaunch());
        }
        _scheduleWidgetSync();
      });
      ref.listen(coupleControllerProvider, (_, next) {
        if (next.hasValue) {
          _scheduleWidgetSync();
          unawaited(_drainNotificationLaunch());
        }
      });
      ref.listen(profileControllerProvider, (_, next) {
        if (next.hasValue) {
          _scheduleWidgetSync();
          unawaited(_drainNotificationLaunch());
        }
      });
      ref.listen(coupleCharacterControllerProvider, (_, next) {
        if (next.hasValue) {
          _scheduleWidgetSync();
        }
      });
      ref.listen(coupleRecordingOverviewControllerProvider, (_, next) {
        if (next.hasValue) {
          _scheduleWidgetSync();
        }
      });
      ref.listen(todayStoryLoopSummaryProvider, (_, next) {
        if (next.hasValue) {
          _scheduleWidgetSync();
        }
      });
    }

    return MaterialApp.router(
      title: 'Vinscent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }

  bool get _supportsHomeWidgets => Platform.isAndroid || Platform.isIOS;

  bool get _supportsPushNotifications => Platform.isAndroid || Platform.isIOS;
}
