import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recordings/application/recording_attention_state.dart';
import 'app_shell.dart';
import 'widgets/app_header.dart';

class HomeTabFrame extends ConsumerWidget {
  const HomeTabFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingAttention = ref.watch(recordingAttentionStateProvider);
    return Column(
      children: [
        AppHeader(
          height: AppShell.headerHeight,
          showRelationshipDayCount: true,
          showRecordingAttention: recordingAttention.hasUnread,
          onRecordingLibraryPressed: () => context.push('/home/recordings'),
          onSettingsPressed: () => context.push('/settings'),
        ),
        Expanded(child: child),
      ],
    );
  }
}
