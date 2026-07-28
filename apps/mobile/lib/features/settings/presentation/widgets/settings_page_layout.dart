import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_page_layout.dart';
import 'settings_page_header.dart';

class SettingsPageLayout extends StatelessWidget {
  const SettingsPageLayout({
    super.key,
    required this.title,
    required this.onBackPressed,
    required this.child,
    this.action,
  });

  final String title;
  final VoidCallback onBackPressed;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppPageLayout(
      header: SettingsPageHeader(
        title: title,
        onBackPressed: onBackPressed,
        action: action,
      ),
      child: child,
    );
  }
}
