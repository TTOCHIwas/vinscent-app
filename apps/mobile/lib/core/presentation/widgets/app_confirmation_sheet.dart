import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'word_boundary_text.dart';

Future<bool> showAppConfirmationSheet({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = '취소',
  bool isDestructive = true,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => AppConfirmationSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );

  return result == true;
}

class AppConfirmationSheet extends StatelessWidget {
  const AppConfirmationSheet({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
    this.message,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    return SafeArea(
      top: false,
      child: Padding(
        key: const Key('app-confirmation-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 20),
            WordBoundaryText(title, style: AppTextStyles.sectionTitle),
            if (message != null) ...[
              const SizedBox(height: 8),
              WordBoundaryText(
                message,
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _ConfirmationAction(
              actionKey: const Key('app-confirmation-confirm'),
              label: confirmLabel,
              isDestructive: isDestructive,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            _ConfirmationAction(
              actionKey: const Key('app-confirmation-cancel'),
              label: cancelLabel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationAction extends StatelessWidget {
  const _ConfirmationAction({
    required this.actionKey,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final Key actionKey;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : AppColors.textPrimary;
    final backgroundColor = isDestructive
        ? color.withValues(alpha: 0.08)
        : AppColors.actionDisabled;

    return SizedBox(
      height: 52,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: actionKey,
          onTap: onPressed,
          splashColor: AppColors.settingsPressed,
          highlightColor: AppColors.settingsPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.homeBodyMedium.copyWith(color: color),
            ),
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
