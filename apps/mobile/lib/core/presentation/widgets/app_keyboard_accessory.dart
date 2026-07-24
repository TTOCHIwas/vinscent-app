import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'app_answer_input.dart';
import 'app_header_text_action.dart';

class AppKeyboardAccessoryLayout extends StatefulWidget {
  const AppKeyboardAccessoryLayout({
    super.key,
    required this.child,
    required this.accessory,
    required this.isActive,
  });

  final Widget child;
  final Widget accessory;
  final bool isActive;

  @override
  State<AppKeyboardAccessoryLayout> createState() =>
      _AppKeyboardAccessoryLayoutState();
}

class _AppKeyboardAccessoryLayoutState extends State<AppKeyboardAccessoryLayout>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = View.of(context).viewInsets.bottom > 0;

    return Column(
      children: [
        Expanded(child: widget.child),
        if (widget.isActive && keyboardVisible)
          TextFieldTapRegion(child: widget.accessory),
      ],
    );
  }
}

class AppKeyboardAccessoryBar extends StatelessWidget {
  const AppKeyboardAccessoryBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
    this.minimumHeight = 48,
  });

  final Widget child;
  final EdgeInsets padding;
  final double minimumHeight;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minimumHeight),
          child: child,
        ),
      ),
    );
  }
}

class AppTextInputKeyboardAccessory extends StatelessWidget {
  const AppTextInputKeyboardAccessory({
    super.key,
    required this.characterCount,
    required this.maxLength,
    required this.actionLabel,
    required this.loadingLabel,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
    required this.horizontalPadding,
    this.characterCountKey,
    this.actionKey,
  });

  final int characterCount;
  final int maxLength;
  final String actionLabel;
  final String loadingLabel;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;
  final double horizontalPadding;
  final Key? characterCountKey;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    return AppKeyboardAccessoryBar(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: AppAnswerCharacterCount(
              key: characterCountKey,
              characterCount: characterCount,
              maxLength: maxLength,
              alignment: Alignment.centerLeft,
            ),
          ),
          AppHeaderTextAction(
            key: actionKey,
            label: actionLabel,
            loadingLabel: loadingLabel,
            enabled: enabled,
            isLoading: isLoading,
            onPressed: onPressed,
            alignment: Alignment.centerRight,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
