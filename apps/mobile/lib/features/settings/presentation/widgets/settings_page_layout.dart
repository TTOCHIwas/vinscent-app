import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'settings_page_header.dart';

class SettingsPageLayout extends StatelessWidget {
  const SettingsPageLayout({
    super.key,
    required this.title,
    required this.onBackPressed,
    required this.child,
  });

  final String title;
  final VoidCallback onBackPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.settingsBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SettingsPageHeader(title: title, onBackPressed: onBackPressed),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
