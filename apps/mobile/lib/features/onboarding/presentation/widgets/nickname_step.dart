import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class NicknameStep extends StatefulWidget {
  const NicknameStep({
    super.key,
    required this.nickname,
    required this.isValid,
    required this.onChanged,
    required this.onClear,
  });

  final String nickname;
  final bool isValid;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<NicknameStep> createState() => _NicknameStepState();
}

class _NicknameStepState extends State<NicknameStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.nickname);
  }

  @override
  void didUpdateWidget(covariant NicknameStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nickname != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.nickname,
        selection: TextSelection.collapsed(offset: widget.nickname.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hintColor = widget.isValid
        ? AppColors.success
        : AppColors.textPlaceholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('닉네임을\n입력해 주세요.', style: AppTextStyles.onboardingTitle),
        const SizedBox(height: 54),
        TextField(
          controller: _controller,
          autofocus: true,
          cursorColor: AppColors.textPrimary,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.done,
          style: AppTextStyles.onboardingInput,
          decoration: InputDecoration(
            hintText: '닉네임을 입력해 주세요.',
            hintStyle: AppTextStyles.onboardingInput.copyWith(
              color: AppColors.textPlaceholder,
            ),
            suffixIcon: widget.nickname.isEmpty
                ? null
                : IconButton(
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.cancel),
                    color: AppColors.textPlaceholder,
                    tooltip: '입력 지우기',
                  ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.check_circle, color: hintColor, size: 18),
            const SizedBox(width: 6),
            Text(
              '닉네임 2 ~ 8자',
              style: AppTextStyles.onboardingHint.copyWith(color: hintColor),
            ),
          ],
        ),
      ],
    );
  }
}
