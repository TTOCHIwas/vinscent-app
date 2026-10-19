import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MonthlyRetrospectiveSection extends StatelessWidget {
  const MonthlyRetrospectiveSection({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MonthlySectionHeader(title: title, description: description),
      const SizedBox(height: 20),
      child,
    ],
  );
}

class MonthlySectionHeader extends StatelessWidget {
  const MonthlySectionHeader({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: AppTextStyles.sectionTitle),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        style: AppTextStyles.homeCharacterLabel.copyWith(
          color: AppColors.textMuted,
        ),
      ),
    ],
  );
}
