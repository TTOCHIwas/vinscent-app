import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../characters/presentation/widgets/couple_character_avatar.dart';

class CoupleSetupWaitingScreen extends StatelessWidget {
  const CoupleSetupWaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CharacterPlaceholder(label: '캐릭터', size: 180),
              SizedBox(height: 24),
              Text('설정 중입니다.', style: AppTextStyles.shellTitle),
            ],
          ),
        ),
      ),
    );
  }
}
