import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const socialButton = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 24 / 16,
    letterSpacing: 0,
  );

  static const logoLabel = TextStyle(
    color: AppColors.logoBackground,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
}
