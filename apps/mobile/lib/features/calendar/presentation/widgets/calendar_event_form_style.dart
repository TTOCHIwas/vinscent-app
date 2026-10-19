import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_input_style.dart';

abstract final class CalendarEventFormStyle {
  static final segmentedButton = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return null;
      }
      return states.contains(WidgetState.selected)
          ? AppColors.selection
          : AppColors.background;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return null;
      }
      return states.contains(WidgetState.selected)
          ? AppColors.onSelection
          : AppColors.textPrimary;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return null;
      }
      return BorderSide(
        color: states.contains(WidgetState.selected)
            ? AppColors.selection
            : AppColors.settingsDivider,
      );
    }),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  static InputDecoration titleInputDecoration(String hintText) {
    return AppInputStyle.decoration(hintText: hintText, counterText: '');
  }

  static InputDecoration inputDecoration(
    String hintText, {
    bool hideCounter = false,
  }) {
    return AppInputStyle.decoration(
      hintText: hintText,
      counterText: hideCounter ? '' : null,
    );
  }
}
