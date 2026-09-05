import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'word_boundary_text.dart';

Future<bool> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = '취소',
  bool isDestructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (context) => AppConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
  return result == true;
}

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth -
                    MediaQuery.viewInsetsOf(context).horizontal -
                    48)
                .clamp(0.0, 400.0);
        final textWidth = (width - 48).clamp(0.0, 352.0);
        final message = this.message;

        return AlertDialog(
          key: const Key('app-confirmation-dialog'),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: BoxConstraints.tightFor(width: width),
          insetPadding: const EdgeInsets.all(24),
          scrollable: true,
          titlePadding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            message == null ? 20 : 0,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          buttonPadding: const EdgeInsets.symmetric(horizontal: 4),
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowAlignment: OverflowBarAlignment.end,
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 4,
          // Bound the layout-based text before AlertDialog measures intrinsic width.
          title: SizedBox(
            width: textWidth,
            child: WordBoundaryText(title, style: AppTextStyles.sectionTitle),
          ),
          content: message == null
              ? null
              : SizedBox(
                  width: textWidth,
                  child: WordBoundaryText(
                    message,
                    style: AppTextStyles.homeBody.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
          actions: [
            _action(
              context,
              key: const Key('app-confirmation-cancel'),
              label: cancelLabel,
              color: AppColors.textMuted,
              result: false,
            ),
            _action(
              context,
              key: const Key('app-confirmation-confirm'),
              label: confirmLabel,
              color: isDestructive
                  ? Theme.of(context).colorScheme.error
                  : AppColors.textPrimary,
              result: true,
            ),
          ],
        );
      },
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required String label,
    required Color color,
    required bool result,
  }) {
    return TextButton(
      key: key,
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: AppTextStyles.homeBodyMedium,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => Navigator.of(context).pop(result),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
