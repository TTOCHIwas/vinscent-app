import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.height,
    required this.onSettingsPressed,
  });

  final double height;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text('앱 이름', style: AppTextStyles.shellTitle),
          Positioned(
            right: 32,
            top: 0,
            bottom: 0,
            child: Center(
              child: Semantics(
                button: true,
                label: '설정',
                child: InkWell(
                  onTap: onSettingsPressed,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Text(
                      '설정',
                      style: AppTextStyles.shellNavigation.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
