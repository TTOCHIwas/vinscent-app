import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'app_back_button.dart';

class AppSetupPage extends StatelessWidget {
  const AppSetupPage({
    super.key,
    required this.child,
    this.header,
    this.bottomAction,
    this.centerContent = false,
    this.maxContentWidth = 520,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
  });

  final Widget child;
  final Widget? header;
  final Widget? bottomAction;
  final bool centerContent;
  final double maxContentWidth;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    final bottomAction = this.bottomAction;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            ?header,
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final content = Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: SizedBox(width: double.infinity, child: child),
                    ),
                  );

                  return SingleChildScrollView(
                    key: const Key('app-setup-page-scroll-view'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: contentPadding,
                    child: centerContent
                        ? SizedBox(
                            height:
                                (constraints.maxHeight -
                                        contentPadding.vertical)
                                    .clamp(0, double.infinity),
                            child: content,
                          )
                        : content,
                  );
                },
              ),
            ),
            if (bottomAction != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: bottomAction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AppSetupHeader extends StatelessWidget {
  const AppSetupHeader({
    super.key,
    this.onBackPressed,
    this.action,
    this.currentStep,
    this.totalSteps,
  }) : assert(
         (currentStep == null && totalSteps == null) ||
             (currentStep != null &&
                 totalSteps != null &&
                 currentStep > 0 &&
                 currentStep <= totalSteps),
       );

  final VoidCallback? onBackPressed;
  final Widget? action;
  final int? currentStep;
  final int? totalSteps;

  @override
  Widget build(BuildContext context) {
    final currentStep = this.currentStep;
    final totalSteps = this.totalSteps;

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (onBackPressed case final onBackPressed?)
              Align(
                alignment: Alignment.centerLeft,
                child: AppBackButton(onPressed: onBackPressed, tooltip: '이전'),
              ),
            if (currentStep != null && totalSteps != null)
              Semantics(
                label: '$totalSteps단계 중 $currentStep단계',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 1; index <= totalSteps; index++) ...[
                        if (index > 1) const SizedBox(width: 6),
                        AnimatedContainer(
                          key: Key('app-setup-step-$index'),
                          duration: const Duration(milliseconds: 180),
                          width: index == currentStep ? 24 : 16,
                          height: 3,
                          decoration: BoxDecoration(
                            color: index <= currentStep
                                ? AppColors.brandAccent
                                : AppColors.settingsDivider,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (action case final action?)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
