import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'widgets/app_header.dart';

class HomeTabFrame extends StatelessWidget {
  const HomeTabFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(
          height: AppShell.headerHeight,
          showRelationshipDayCount: true,
          onRecordingLibraryPressed: () => context.push('/home/recordings'),
          onSettingsPressed: () => context.push('/settings'),
        ),
        Expanded(child: child),
      ],
    );
  }
}
