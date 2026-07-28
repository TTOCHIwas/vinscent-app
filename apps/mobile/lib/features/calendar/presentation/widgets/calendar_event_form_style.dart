import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

abstract final class CalendarEventFormStyle {
  static final segmentedButton = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return null;
      }
      return states.contains(WidgetState.selected)
          ? AppColors.brandAccent
          : AppColors.background;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return null;
      }
      return states.contains(WidgetState.selected)
          ? AppColors.onBrandAction
          : AppColors.textPrimary;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return null;
      }
      return BorderSide(
        color: states.contains(WidgetState.selected)
            ? AppColors.brandAccent
            : AppColors.settingsDivider,
      );
    }),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  static InputDecoration titleInputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.homeBody.copyWith(
        color: AppColors.textPlaceholder,
      ),
      counterText: '',
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: _titleBorder,
      enabledBorder: _titleBorder,
      focusedBorder: _titleBorder,
      disabledBorder: _titleBorder,
    );
  }

  static InputDecoration inputDecoration(
    String hintText, {
    bool hideCounter = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.homeBody.copyWith(
        color: AppColors.textPlaceholder,
      ),
      counterText: hideCounter ? '' : null,
      filled: true,
      fillColor: AppColors.formSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: _border,
      enabledBorder: _border,
      focusedBorder: _border,
      disabledBorder: _border,
    );
  }

  static final _border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide.none,
  );

  static const _titleBorder = UnderlineInputBorder(
    borderSide: BorderSide(color: AppColors.settingsDivider),
  );
}
