import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'ai_generated_content_info_sheet.dart';

class AiGeneratedContentIndicator extends StatelessWidget {
  const AiGeneratedContentIndicator({super.key, this.onReportPressed});

  const AiGeneratedContentIndicator._attached({this.onReportPressed});

  static const _indicatorKey = Key('ai-generated-content-indicator');
  static const _badgeKey = Key('ai-generated-content-badge');
  static const _iconSize = 15.0;

  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _indicatorKey,
      tooltip: 'AI 생성 내용 안내',
      onPressed: () => showAiGeneratedContentInfoSheet(
        context: context,
        onReportPressed: onReportPressed,
      ),
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.standard,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(32),
        maximumSize: const Size.square(32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const SizedBox.square(
        key: _badgeKey,
        dimension: _iconSize,
        child: Icon(
          Icons.auto_awesome_rounded,
          size: _iconSize,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class AiGeneratedContentAttribution extends StatelessWidget {
  const AiGeneratedContentAttribution({super.key, this.onReportPressed});

  static const _attributionKey = Key('ai-generated-content-attribution');
  static const _labelKey = Key('ai-generated-content-label');
  static const _iconSize = 13.0;

  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _attributionKey,
      child: Semantics(
        button: true,
        label: 'AI 생성 내용 안내',
        excludeSemantics: true,
        child: Tooltip(
          message: 'AI 생성 내용 안내',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: AiGeneratedContentIndicator._indicatorKey,
              onTap: () => showAiGeneratedContentInfoSheet(
                context: context,
                onReportPressed: onReportPressed,
              ),
              borderRadius: BorderRadius.circular(6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: _iconSize,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'AI 생성',
                        key: _labelKey,
                        style: AppTextStyles.aiGeneratedAttribution,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AiGeneratedContentBadgeOverlay extends StatelessWidget {
  const AiGeneratedContentBadgeOverlay({
    super.key,
    required this.child,
    this.showIndicator = true,
    this.onReportPressed,
    this.attachmentBottomInset = 0,
    this.reserveIndicatorSpace = false,
  });

  final Widget child;
  final bool showIndicator;
  final VoidCallback? onReportPressed;
  final double attachmentBottomInset;
  final bool reserveIndicatorSpace;

  static const contentBottomPadding = 18.0;

  @override
  Widget build(BuildContext context) {
    if (!showIndicator) {
      return child;
    }

    final presentedChild = reserveIndicatorSpace
        ? Padding(
            padding: EdgeInsets.only(
              bottom: contentBottomPadding + attachmentBottomInset,
            ),
            child: child,
          )
        : child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        presentedChild,
        Positioned(
          right: 0,
          bottom: attachmentBottomInset,
          child: AiGeneratedContentIndicator._attached(
            onReportPressed: onReportPressed,
          ),
        ),
      ],
    );
  }
}
