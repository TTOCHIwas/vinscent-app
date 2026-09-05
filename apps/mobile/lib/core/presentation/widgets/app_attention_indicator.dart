import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppAttentionIndicator extends StatelessWidget {
  const AppAttentionIndicator({
    super.key,
    required this.isVisible,
    required this.child,
    this.semanticsLabel,
    this.alignment = Alignment.topRight,
    this.offset = const Offset(2, -2),
    this.size = 8,
  });

  final bool isVisible;
  final Widget child;
  final String? semanticsLabel;
  final AlignmentGeometry alignment;
  final Offset offset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isVisible ? semanticsLabel : null,
      child: Badge(
        isLabelVisible: isVisible,
        backgroundColor: AppColors.attention,
        alignment: alignment,
        offset: offset,
        smallSize: size,
        child: child,
      ),
    );
  }
}
