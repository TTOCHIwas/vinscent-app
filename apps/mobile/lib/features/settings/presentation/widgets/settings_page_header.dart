import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_back_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.onBackPressed,
  });

  final String title;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppBackButton(
              onPressed: onBackPressed,
              color: AppColors.textPrimary,
            ),
          ),
          Text(title, style: AppTextStyles.shellTitle),
        ],
      ),
    );
  }
}
