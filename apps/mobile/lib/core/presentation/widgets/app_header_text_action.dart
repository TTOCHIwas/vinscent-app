import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppHeaderTextAction extends StatelessWidget {
  const AppHeaderTextAction({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });

  final String label;
  final String loadingLabel;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? loadingLabel : label,
      excludeSemantics: true,
      child: SizedBox(
        width: 72,
        height: 44,
        child: TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            disabledForegroundColor: AppColors.textPlaceholder,
            padding: padding,
          ),
          child: Align(
            alignment: alignment,
            child: isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.textPrimary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}
