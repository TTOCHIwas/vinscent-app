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
  static const _horizontalInset = 24.0;
  static const _minimumWidth = 280.0;
  static const _maximumWidth = 400.0;
  static const _dividerHeight = 1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            (constraints.maxWidth -
                    MediaQuery.viewInsetsOf(context).horizontal -
                    _screenInset * 2)
                .clamp(0.0, _maximumWidth);
        final minWidth = maxWidth.clamp(0.0, _minimumWidth);
        final maxTextWidth = (maxWidth - _horizontalInset * 2).clamp(
          0.0,
          _maximumWidth,
        );
        final message = this.message;

        return AlertDialog(
          key: const Key('app-confirmation-dialog'),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
          insetPadding: const EdgeInsets.all(_screenInset),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _horizontalInset,
                      28,
                      _horizontalInset,
                      24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ConfirmationText(
                          title,
                          maxWidth: maxTextWidth,
                          style: AppTextStyles.sectionTitle,
                          textAlign: TextAlign.center,
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 8),
                          _ConfirmationText(
                            message,
                            maxWidth: maxTextWidth,
                            style: AppTextStyles.homeBody.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const _ConfirmationDivider(
                dividerKey: Key('app-confirmation-divider-before-confirm'),
              ),
              _ConfirmationAction(
                buttonKey: const Key('app-confirmation-confirm'),
                label: confirmLabel,
                color: isDestructive
                    ? Theme.of(context).colorScheme.error
                    : AppColors.textPrimary,
                result: true,
                maxTextWidth: maxTextWidth,
              ),
              const _ConfirmationDivider(
                dividerKey: Key('app-confirmation-divider-before-cancel'),
              ),
              _ConfirmationAction(
                buttonKey: const Key('app-confirmation-cancel'),
                label: cancelLabel,
                color: AppColors.textPrimary,
                result: false,
                maxTextWidth: maxTextWidth,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfirmationDivider extends StatelessWidget {
  const _ConfirmationDivider({required this.dividerKey});

  final Key dividerKey;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: dividerKey,
      color: AppColors.settingsDivider,
      child: const SizedBox(height: AppConfirmationDialog._dividerHeight),
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
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConfirmationDialog._horizontalInset,
          vertical: 16,
        ),
        shape: const RoundedRectangleBorder(),
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
