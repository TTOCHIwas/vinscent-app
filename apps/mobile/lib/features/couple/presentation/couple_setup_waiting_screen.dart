import 'package:flutter/material.dart';

import '../../../core/presentation/widgets/app_setup_page.dart';
import '../../../core/presentation/widgets/character_placeholder.dart';
import '../../../core/theme/app_text_styles.dart';

class CoupleSetupWaitingScreen extends StatelessWidget {
  const CoupleSetupWaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppSetupPage(
      header: const AppSetupHeader(),
      centerContent: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final characterSize = (constraints.maxWidth * 0.42)
              .clamp(180.0, 220.0)
              .toDouble();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CharacterPlaceholder(label: '캐릭터', size: characterSize),
              const SizedBox(height: 24),
              const Text('설정 중입니다.', style: AppTextStyles.shellTitle),
            ],
          );
        },
      ),
    );
  }
}
