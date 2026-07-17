import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_icons.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_page_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: '설정',
      onBackPressed: () => context.go('/home'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SettingsGroup(
            key: const Key('settings-group-notifications'),
            label: '알림',
            dividerIndent: 58,
            children: [
              SettingsNavigationRow(
                key: const Key('settings-row-notifications'),
                icon: AppIcons.alarm,
                title: '알림 설정',
                onTap: () => context.push('/settings/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SettingsGroup(
            key: const Key('settings-group-couple'),
            label: '커플',
            dividerIndent: 58,
            children: [
              SettingsNavigationRow(
                key: const Key('settings-row-character'),
                icon: AppIcons.user,
                title: '캐릭터 꾸미기',
                onTap: () => context.push('/settings/character'),
              ),
              SettingsNavigationRow(
                key: const Key('settings-row-couple'),
                icon: AppIcons.heart,
                title: '커플 설정',
                onTap: () => context.push('/settings/couple'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
