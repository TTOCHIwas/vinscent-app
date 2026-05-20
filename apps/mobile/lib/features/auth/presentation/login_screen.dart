import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 56, 32, 34),
          child: Column(
            children: [
              const Expanded(child: Center(child: _LogoMark())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Column(
                  spacing: 8,
                  children: const [
                    SizedBox(height: 56, width: double.infinity),
                    SizedBox(height: 56, width: double.infinity),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.logoBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: 80,
        height: 80,
        child: Center(child: Text('로고', style: AppTextStyles.logoLabel)),
      ),
    );
  }
}
