import 'package:flutter/material.dart';

import 'router.dart';
import '../core/theme/app_theme.dart';

class VinscentApp extends StatelessWidget {
  const VinscentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vinscent',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
