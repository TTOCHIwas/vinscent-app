import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/presentation/widgets/profile_display_name_field.dart';

class NicknameStep extends StatelessWidget {
  const NicknameStep({
    super.key,
    required this.nickname,
    required this.isValid,
    required this.onChanged,
    required this.onClear,
    required this.onSubmitted,
  });

  final String nickname;
  final bool isValid;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('어떻게 불러주면 될까?', style: AppTextStyles.onboardingTitle),
        const SizedBox(height: 8),
        Text(
          '둘만의 공간에서 사용할 이름이야',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 32),
        ProfileDisplayNameField(
          autofocus: true,
          textInputAction: TextInputAction.next,
          value: nickname,
          isValid: isValid,
          onChanged: onChanged,
          onClear: onClear,
          onSubmitted: onSubmitted,
        ),
      ],
    );
  }
}
