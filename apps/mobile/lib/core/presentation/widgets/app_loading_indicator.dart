import 'package:flutter/cupertino.dart';

import '../../theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.radius = 10});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: CupertinoActivityIndicator(
        color: AppColors.textMuted,
        radius: radius,
      ),
    );
  }
}
