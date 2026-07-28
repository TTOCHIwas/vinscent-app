import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AiGeneratedContentIndicator extends StatelessWidget {
  const AiGeneratedContentIndicator({super.key, this.onPressed});

  static const _indicatorKey = Key('ai-generated-content-indicator');
  static const _iconSize = 15.0;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    if (onPressed == null) {
      return Tooltip(
        message: 'AI 생성',
        child: Semantics(
          key: _indicatorKey,
          label: 'AI 생성',
          image: true,
          child: const ExcludeSemantics(
            child: Icon(
              Icons.auto_awesome_rounded,
              size: _iconSize,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return IconButton(
      key: _indicatorKey,
      tooltip: 'AI 생성 내용',
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: const Icon(
        Icons.auto_awesome_rounded,
        size: _iconSize,
        color: AppColors.textMuted,
      ),
    );
  }
}
