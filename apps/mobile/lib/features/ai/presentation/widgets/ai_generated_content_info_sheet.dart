import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

Future<void> showAiGeneratedContentInfoSheet({
  required BuildContext context,
  VoidCallback? onReportPressed,
}) async {
  final shouldReport = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) =>
        AiGeneratedContentInfoSheet(canReport: onReportPressed != null),
  );

  if (shouldReport == true && context.mounted) {
    onReportPressed?.call();
  }
}

class AiGeneratedContentInfoSheet extends StatelessWidget {
  const AiGeneratedContentInfoSheet({super.key, required this.canReport});

  final bool canReport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        key: const Key('ai-generated-content-info-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI가 만든 내용이에요',
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            WordBoundaryText(
              'AI가 만든 내용은 정확하지 않거나 기대와 다를 수 있어요',
              style: AppTextStyles.homeBody.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            if (canReport) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.settingsDivider),
              const SizedBox(height: 4),
              _ReportAction(onPressed: () => Navigator.of(context).pop(true)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportAction extends StatelessWidget {
  const _ReportAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('ai-generated-content-report'),
        onTap: onPressed,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          height: 52,
          child: Row(
            children: [
              SizedBox(width: 12),
              Icon(Icons.flag_outlined, size: 22, color: AppColors.textMuted),
              SizedBox(width: 14),
              Expanded(
                child: Text('문제 신고', style: AppTextStyles.homeBodyMedium),
              ),
              SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.settingsDivider,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(width: 36, height: 4),
    );
  }
}
