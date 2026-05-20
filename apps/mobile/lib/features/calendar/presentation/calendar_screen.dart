import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('달력', style: AppTextStyles.homeBodyMedium));
  }
}
