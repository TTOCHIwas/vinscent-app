import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('설정', style: AppTextStyles.homeBodyMedium));
  }
}
