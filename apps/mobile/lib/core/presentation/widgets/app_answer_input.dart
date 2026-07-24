import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class AppAnswerInput extends StatelessWidget {
  const AppAnswerInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.expands = false,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.enforceMaxLength = true,
    this.hintText = '답변을 남겨봐',
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final bool expands;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool enforceMaxLength;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      expands: expands,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: maxLength == null
          ? null
          : enforceMaxLength
          ? MaxLengthEnforcement.enforced
          : MaxLengthEnforcement.none,
      buildCounter:
          (
            context, {
            required currentLength,
            required isFocused,
            required maxLength,
          }) => null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      style: AppTextStyles.homeBody.copyWith(height: 1.55),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.homeBody.copyWith(
          color: AppColors.textPlaceholder,
        ),
        filled: true,
        fillColor: AppColors.settingsIconBackground,
        contentPadding: const EdgeInsets.all(18),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
        disabledBorder: border,
      ),
    );
  }
}

class AppAnswerCharacterCount extends StatelessWidget {
  const AppAnswerCharacterCount({
    super.key,
    required this.characterCount,
    required this.maxLength,
    this.alignment = Alignment.centerRight,
  });

  final int characterCount;
  final int maxLength;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final color = characterCount > maxLength
        ? Colors.redAccent
        : AppColors.textMuted;

    return SizedBox(
      height: 32,
      child: Align(
        alignment: alignment,
        child: Text(
          '$characterCount / $maxLength',
          style: AppTextStyles.homeCharacterLabel.copyWith(color: color),
        ),
      ),
    );
  }
}
