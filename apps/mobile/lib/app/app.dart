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
import '../features/home_widgets/application/home_widget_sync_service.dart';
import '../features/notifications/application/push_token_controller.dart';
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
  Timer? _widgetSyncTimer;
  Uri? _pendingWidgetUri;
  bool _isHandlingWidgetLaunch = false;
  bool _isWidgetSyncRunning = false;
  bool _isWidgetSyncQueued = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      final coordinator = ref.read(homeWidgetLaunchCoordinatorProvider);
      _widgetClickSubscription = coordinator.widgetClicks.listen(
        _queueWidgetLaunch,
      );
      _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((_) {
        _scheduleWidgetSync();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          coordinator.initiallyLaunchedFromWidget().then(_queueWidgetLaunch),
        );
        _scheduleWidgetSync();
      });
    }
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _widgetSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    if (!Platform.isAndroid) {
      return;
    }
    _widgetSyncTimer?.cancel();
    _widgetSyncTimer = Timer(const Duration(milliseconds: 350), () {
      _widgetSyncTimer = null;
      unawaited(_runWidgetSync());
    });
  }

  Future<void> _runWidgetSync() async {
    if (_isWidgetSyncRunning) {
      _isWidgetSyncQueued = true;
      return;
    }

    _isWidgetSyncRunning = true;
    try {
      do {
        _isWidgetSyncQueued = false;
        await ref.read(homeWidgetSyncServiceProvider).synchronizeSafely();
      } while (_isWidgetSyncQueued && mounted);
    } finally {
      _isWidgetSyncRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.watch(pushTokenControllerProvider);
    if (Platform.isAndroid) {
      ref.listen(authControllerProvider, (_, next) {
        if (next == AuthStatus.authenticated) {
          unawaited(_drainWidgetLaunch());
        }
        _scheduleWidgetSync();
      });
      ref.listen(coupleControllerProvider, (_, next) {
        if (next.hasValue) {
          _scheduleWidgetSync();
        }
      });
      ref.listen(profileControllerProvider, (_, next) {
        if (next.hasValue) {
          _scheduleWidgetSync();
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
}
