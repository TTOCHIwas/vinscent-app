import 'package:flutter/material.dart';

import '../../assets/app_icons.dart';
import '../../theme/app_colors.dart';
import 'app_svg_icon.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    required this.onPressed,
    this.color,
    this.iconSize = 28,
    this.buttonSize = 48,
    this.tooltip = '뒤로가기',
  });

  final VoidCallback? onPressed;
  final Color? color;
  final double iconSize;
  final double buttonSize;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? IconTheme.of(context).color ?? AppColors.textPrimary;

    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(
        width: buttonSize,
        height: buttonSize,
      ),
      tooltip: tooltip,
      icon: AppSvgIcon(AppIcons.back, size: iconSize, color: iconColor),
    );
  }
}
