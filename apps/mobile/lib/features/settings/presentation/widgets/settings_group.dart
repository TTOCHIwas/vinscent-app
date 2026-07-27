import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.label,
    this.dividerIndent = 16,
  });

  final String? label;
  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label case final label?) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              label,
              style: AppTextStyles.homeCharacterLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: AppColors.settingsSurface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index < children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: dividerIndent,
                      color: AppColors.settingsDivider,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsNavigationRow extends StatelessWidget {
  const SettingsNavigationRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final String icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.settingsIconBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppSvgIcon(
                    icon,
                    size: 18,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTextStyles.homeBody)),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 24,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(title, style: AppTextStyles.homeBody),
        subtitle: switch (subtitle) {
          final subtitle? => Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle,
              style: AppTextStyles.homeCharacterLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          null => null,
        },
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsStatusRow extends StatelessWidget {
  const SettingsStatusRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.isActionLoading = false,
    this.showCompleted = false,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isActionLoading;
  final bool showCompleted;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.settingsIconBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: AppSvgIcon(
                icon,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: AppTextStyles.homeBody),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.homeCharacterLabel.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isActionLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (actionLabel case final actionLabel?)
              TextButton(
                onPressed: onActionPressed,
                child: Text(actionLabel),
              )
            else if (showCompleted)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 22,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
