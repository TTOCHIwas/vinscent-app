import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_page_header.dart';

class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.onBackPressed,
    this.action,
  });

  final String title;
  final VoidCallback onBackPressed;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: title,
      onBackPressed: onBackPressed,
      action: action,
    );
  }
}
