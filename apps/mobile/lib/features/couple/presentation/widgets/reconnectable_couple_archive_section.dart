import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../safety/data/user_block.dart';

class ReconnectableCoupleArchiveSection extends StatelessWidget {
  const ReconnectableCoupleArchiveSection({
    super.key,
    required this.archives,
    required this.enabled,
    required this.processingCoupleId,
    required this.onSelected,
  });

  final List<ReconnectableCoupleArchive> archives;
  final bool enabled;
  final String? processingCoupleId;
  final ValueChanged<ReconnectableCoupleArchive> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            '이전 기록',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Material(
            color: AppColors.settingsSurface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < archives.length; index++) ...[
                  _ReconnectableArchiveRow(
                    archive: archives[index],
                    enabled: enabled,
                    isLoading: processingCoupleId == archives[index].coupleId,
                    onTap: () => onSelected(archives[index]),
                  ),
                  if (index < archives.length - 1)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      indent: 52,
                      color: AppColors.settingsDivider,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReconnectableArchiveRow extends StatelessWidget {
  const _ReconnectableArchiveRow({
    required this.archive,
    required this.enabled,
    required this.isLoading,
    required this.onTap,
  });

  final ReconnectableCoupleArchive archive;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        key: Key('couple-reconnect-archive-${archive.coupleId}'),
        onTap: enabled ? onTap : null,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 24,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${archive.partnerDisplayName}님과 다시 연결',
                        style: AppTextStyles.homeBody,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(archive.archiveExpiresAt)}까지 기존 기록을 이어갈 수 있어',
                        style: AppTextStyles.homeCharacterLabel.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoading)
                  const SizedBox.square(
                    dimension: 20,
                    child: AppLoadingIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
