import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';

class MonthlyRetrospectiveAction extends StatelessWidget {
  const MonthlyRetrospectiveAction({super.key, required this.onPressed});

  static const dimension = 44.0;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '월간 회고',
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(
      width: dimension,
      height: dimension,
    ),
    padding: const EdgeInsets.all(10),
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    icon: const Icon(
      LucideIcons.bookHeart,
      size: 24,
      color: AppColors.textPrimary,
    ),
  );
}
