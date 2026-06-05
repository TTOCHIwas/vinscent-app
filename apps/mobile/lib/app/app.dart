import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date/today_controller.dart';
import '../core/theme/app_theme.dart';
import '../features/notifications/application/push_token_controller.dart';
import 'router.dart';

class VinscentApp extends ConsumerStatefulWidget {
  const VinscentApp({super.key});

  @override
  ConsumerState<VinscentApp> createState() => _VinscentAppState();
}

class _VinscentAppState extends ConsumerState<VinscentApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(todayControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.watch(pushTokenControllerProvider);

    return MaterialApp.router(
      title: 'Vinscent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
