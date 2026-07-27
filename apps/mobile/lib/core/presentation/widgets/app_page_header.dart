import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'app_back_button.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.onBackPressed,
    this.leading,
    this.action,
  }) : assert(onBackPressed == null || leading == null);

  final String title;
  final VoidCallback? onBackPressed;
  final Widget? leading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final leadingWidget =
        leading ??
        switch (onBackPressed) {
          final onBackPressed? => AppBackButton(
            onPressed: onBackPressed,
            color: AppColors.textPrimary,
          ),
          null => null,
        };

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (leadingWidget != null)
              Align(alignment: Alignment.centerLeft, child: leadingWidget),
            Text(title, style: AppTextStyles.shellTitle),
            if (action case final action?)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
