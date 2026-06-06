import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/app_colors.dart';

class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(
    this.assetName, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final String assetName;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? IconTheme.of(context).color ?? AppColors.textPrimary;

    return SizedBox.square(
      dimension: size,
      child: SvgPicture.asset(
        assetName,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: semanticLabel,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      ),
    );
  }
}
