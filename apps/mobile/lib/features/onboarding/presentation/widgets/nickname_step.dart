import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class NicknameStep extends StatefulWidget {
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
        const Text('어떻게 불러주면 될까?', style: AppTextStyles.onboardingTitle),
        const SizedBox(height: 8),
        Text(
          '둘만의 공간에서 사용할 이름이야',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          autofocus: true,
          cursorColor: AppColors.textPrimary,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          inputFormatters: [LengthLimitingTextInputFormatter(8)],
          style: AppTextStyles.onboardingInput,
          decoration: InputDecoration(
            hintText: '닉네임',
            hintStyle: AppTextStyles.onboardingInput.copyWith(
              color: AppColors.textPlaceholder,
            ),
            suffixIcon: widget.nickname.isEmpty
                ? null
                : IconButton(
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.close),
                    color: AppColors.textMuted,
                    tooltip: '입력 지우기',
                  ),
            filled: true,
            fillColor: AppColors.formSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.textPrimary),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          onChanged: widget.onChanged,
          onSubmitted: (_) {
            if (widget.isValid) {
              widget.onSubmitted();
            }
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              widget.isValid ? Icons.check_circle : Icons.info_outline,
              color: hintColor,
              size: 18,
            ),
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
