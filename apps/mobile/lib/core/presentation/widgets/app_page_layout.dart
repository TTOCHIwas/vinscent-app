import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppPageLayout extends StatelessWidget {
  const AppPageLayout({
    super.key,
    required this.header,
    required this.child,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  final Widget header;
  final Widget child;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            header,
            Expanded(
              child: Padding(padding: bodyPadding, child: child),
            ),
          ],
        ),
      ),
    );
  }
}
