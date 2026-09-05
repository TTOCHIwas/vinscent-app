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

  static const _screenInset = 24.0;
  static const _contentInset = 24.0;
  static const _actionInset = 12.0;
  static const _maximumWidth = 400.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            (constraints.maxWidth -
                    MediaQuery.viewInsetsOf(context).horizontal -
                    _screenInset * 2)
                .clamp(0.0, _maximumWidth);
        final maxTextWidth = (maxWidth - _contentInset * 2).clamp(
          0.0,
          _maximumWidth,
        );
        final maxActionTextWidth = (maxTextWidth - _actionInset * 2).clamp(
          0.0,
          _maximumWidth,
        );
        final message = this.message;

        return AlertDialog(
          key: const Key('app-confirmation-dialog'),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: BoxConstraints(maxWidth: maxWidth),
          insetPadding: const EdgeInsets.all(_screenInset),
          scrollable: true,
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.zero,
          actionsPadding: const EdgeInsets.fromLTRB(
            _contentInset,
            0,
            _contentInset,
            16,
          ),
          title: Padding(
            padding: EdgeInsets.fromLTRB(
              _contentInset,
              24,
              _contentInset,
              message == null ? 20 : 0,
            ),
            child: _ConfirmationText(
              title,
              maxWidth: maxTextWidth,
              style: AppTextStyles.sectionTitle,
            ),
          ),
          content: message == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _contentInset,
                    12,
                    _contentInset,
                    20,
                  ),
                  child: _ConfirmationText(
                    message,
                    maxWidth: maxTextWidth,
                    style: AppTextStyles.homeBody.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ConfirmationAction(
                  buttonKey: const Key('app-confirmation-cancel'),
                  label: cancelLabel,
                  color: AppColors.textMuted,
                  result: false,
                  maxTextWidth: maxActionTextWidth,
                ),
                const SizedBox(height: 4),
                _ConfirmationAction(
                  buttonKey: const Key('app-confirmation-confirm'),
                  label: confirmLabel,
                  color: isDestructive
                      ? Theme.of(context).colorScheme.error
                      : AppColors.textPrimary,
                  result: true,
                  maxTextWidth: maxActionTextWidth,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ConfirmationAction extends StatelessWidget {
  const _ConfirmationAction({
    required this.buttonKey,
    required this.label,
    required this.color,
    required this.result,
    required this.maxTextWidth,
  });

  final Key buttonKey;
  final String label;
  final Color color;
  final bool result;
  final double maxTextWidth;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: buttonKey,
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: AppTextStyles.homeBodyMedium,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.all(AppConfirmationDialog._actionInset),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => Navigator.of(context).pop(result),
      child: _ConfirmationText(
        label,
        maxWidth: maxTextWidth,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _ConfirmationText extends StatelessWidget {
  const _ConfirmationText(
    this.text, {
    required this.maxWidth,
    this.style,
    this.textAlign,
  });

  final String text;
  final double maxWidth;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
    // Wrap before intrinsic sizing so the dialog can hug its text without a fixed width.
    final displayText = keepWordsTogether(
      text,
      maxTextWidth: maxWidth,
      style: resolvedStyle,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    return Text(
      displayText,
      style: resolvedStyle,
      textAlign: textAlign,
      semanticsLabel: text,
    );
  }
}
