import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_icons.dart';
import '../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'widgets/settings_page_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsPageHeader(
              title: '설정',
              onBackPressed: () => context.go('/home'),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('알림'),
            const SizedBox(height: 10),
            _SettingsItem(
              icon: AppIcons.alarm,
              title: '알림 설정',
              subtitle: '카테고리별 수신 여부를 관리해요.',
              onTap: () => context.push('/settings/notifications'),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('커플'),
            const SizedBox(height: 10),
            _SettingsItem(
              icon: AppIcons.heart,
              title: '커플 설정',
              subtitle: '연결 해제와 보관 데이터 관리를 진행할 수 있어요.',
              onTap: () => context.push('/settings/couple'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.homeCharacterLabel.copyWith(
        color: AppColors.textMuted,
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              AppSvgIcon(icon, size: 24, color: AppColors.textPrimary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.homeBodyMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.homeCharacterLabel.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
