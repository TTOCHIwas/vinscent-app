import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../couple/application/couple_controller.dart';
import '../../../home/application/day_count.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({
    super.key,
    required this.height,
    required this.showRelationshipDayCount,
    required this.onSettingsPressed,
  });

  final double height;
  final bool showRelationshipDayCount;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget leading = const SizedBox.shrink();
    if (showRelationshipDayCount) {
      leading = ref
          .watch(coupleControllerProvider)
          .when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (couple) {
              if (couple == null || !couple.hasRelationshipStartDate) {
                return const SizedBox.shrink();
              }

              final dayCount = calculateRelationshipDayCount(
                startDate: couple.relationshipStartDate!,
                today: couple.effectiveCurrentDate,
              );
              return Text('D+$dayCount', style: AppTextStyles.shellTitle);
            },
          );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            Semantics(
              button: true,
              label: '설정',
              child: InkWell(
                onTap: onSettingsPressed,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    '설정',
                    style: AppTextStyles.shellNavigation.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
