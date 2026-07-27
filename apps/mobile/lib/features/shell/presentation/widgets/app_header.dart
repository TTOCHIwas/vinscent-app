import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/app_icons.dart';
import '../../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../couple/application/couple_controller.dart';
import '../../../home/application/day_count.dart';

class AppHeader extends ConsumerWidget {
  const AppHeader({
    super.key,
    required this.height,
    required this.showRelationshipDayCount,
    required this.onRecordingLibraryPressed,
    required this.onSettingsPressed,
  });

  final double height;
  final bool showRelationshipDayCount;
  final VoidCallback onRecordingLibraryPressed;
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
              return Text('D+$dayCount', style: AppTextStyles.shellDayCount);
            },
          );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          key: const Key('app-header-layout'),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('app-header-recording-library'),
                  tooltip: '녹음 보관함',
                  onPressed: onRecordingLibraryPressed,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const AppSvgIcon(
                    AppIcons.cassetteTape,
                    size: 24,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('app-header-settings'),
                  tooltip: '설정',
                  onPressed: onSettingsPressed,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 26,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
