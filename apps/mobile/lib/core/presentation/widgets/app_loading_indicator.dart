import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.strokeWidth = 4});

  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      color: AppColors.brandAccent,
      strokeWidth: strokeWidth,
    );
  }
}
