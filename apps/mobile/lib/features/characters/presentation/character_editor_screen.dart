import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class CharacterEditorScreen extends StatelessWidget {
  const CharacterEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.chevron_left, size: 32),
                ),
              ),
              const Text('캐릭터 그리기', style: AppTextStyles.shellTitle),
              const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Text(
                    '저장',
                    style: TextStyle(
                      color: AppColors.actionDisabledContent,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('캐릭터를 그릴 준비를 하고 있어요', style: AppTextStyles.homeBody),
          ),
        ),
      ],
    );
  }
}
