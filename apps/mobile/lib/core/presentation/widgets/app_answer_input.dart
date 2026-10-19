import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_input_style.dart';
import '../../theme/app_text_styles.dart';

enum AppAnswerInputPresentation { writing, composer }

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
    this.presentation = AppAnswerInputPresentation.writing,
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
  final AppAnswerInputPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return CupertinoTextField.borderless(
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
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlignVertical: TextAlignVertical.top,
      style: AppInputStyle.textStyle,
      decoration: presentation == AppAnswerInputPresentation.composer
          ? BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(18),
            )
          : null,
      padding: presentation == AppAnswerInputPresentation.composer
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(vertical: 12),
      placeholder: hintText,
      placeholderStyle: AppInputStyle.textStyle.copyWith(
        color: CupertinoColors.placeholderText,
      ),
      cursorColor: AppInputStyle.focusColor,
      keyboardAppearance: Brightness.light,
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
