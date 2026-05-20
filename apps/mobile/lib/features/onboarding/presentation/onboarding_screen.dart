import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Center(child: Text('기본 프로필을 입력해 주세요.'))),
    );
  }
}
