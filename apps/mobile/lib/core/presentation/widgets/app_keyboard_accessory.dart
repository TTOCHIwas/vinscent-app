import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'app_action_tone.dart';
import 'app_answer_input.dart';
import 'app_header_text_action.dart';

class AppKeyboardVisibility extends InheritedWidget {
  const AppKeyboardVisibility({
    super.key,
    required this.isVisible,
    required super.child,
  });

  final bool isVisible;

  static bool of(BuildContext context) {
    final visibility = context
        .dependOnInheritedWidgetOfExactType<AppKeyboardVisibility>();
    return visibility?.isVisible ?? MediaQuery.viewInsetsOf(context).bottom > 0;
  }

  @override
  bool updateShouldNotify(AppKeyboardVisibility oldWidget) {
    return isVisible != oldWidget.isVisible;
  }
}

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

    return AppKeyboardVisibility(
      isVisible: keyboardVisible,
      child: Column(
        children: [
          Expanded(child: widget.child),
          if (widget.isActive && keyboardVisible)
            TextFieldTapRegion(child: widget.accessory),
        ],
      ),
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
    this.actionIcon,
    this.actionTone = AppActionTone.neutral,
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
  final Widget? actionIcon;
  final AppActionTone actionTone;

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
          if (actionIcon case final actionIcon?)
            _KeyboardAccessoryIconAction(
              key: actionKey,
              label: actionLabel,
              loadingLabel: loadingLabel,
              enabled: enabled,
              isLoading: isLoading,
              onPressed: onPressed,
              icon: actionIcon,
              tone: actionTone,
            )
          else
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

class _KeyboardAccessoryIconAction extends StatelessWidget {
  const _KeyboardAccessoryIconAction({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String loadingLabel;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;
  final Widget icon;
  final AppActionTone tone;

  @override
  Widget build(BuildContext context) {
    final activeBackgroundColor = switch (tone) {
      AppActionTone.neutral => AppColors.actionPrimary,
      AppActionTone.brand => AppColors.brandAction,
      AppActionTone.secondary => AppColors.background,
    };
    final activeContentColor = switch (tone) {
      AppActionTone.neutral => AppColors.textInverse,
      AppActionTone.brand => AppColors.onBrandAction,
      AppActionTone.secondary => AppColors.textPrimary,
    };
    final baseStyle = IconButton.styleFrom(
      fixedSize: const Size.square(44),
      backgroundColor: activeBackgroundColor,
      foregroundColor: activeContentColor,
      disabledBackgroundColor: isLoading
          ? activeBackgroundColor
          : AppColors.actionDisabled,
      disabledForegroundColor: isLoading
          ? activeContentColor
          : AppColors.actionDisabledContent,
      side: tone == AppActionTone.secondary
          ? const BorderSide(color: AppColors.wireframeBorder)
          : null,
      shape: const CircleBorder(),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? loadingLabel : label,
      excludeSemantics: true,
      child: IconButton(
        tooltip: label,
        onPressed: enabled && !isLoading ? onPressed : null,
        style: tone == AppActionTone.brand
            ? baseStyle.copyWith(
                overlayColor: const WidgetStatePropertyAll(
                  AppColors.brandPressed,
                ),
              )
            : baseStyle,
        icon: isLoading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  color: activeContentColor,
                  strokeWidth: 2,
                ),
              )
            : icon,
      ),
    );
  }
}
