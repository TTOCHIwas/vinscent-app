import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'ai_generated_content_info_sheet.dart';

class AiGeneratedContentIndicator extends StatelessWidget {
  const AiGeneratedContentIndicator({
    super.key,
    this.onReportPressed,
    this.iconAlignment = AlignmentDirectional.bottomStart,
  });

  static const _indicatorKey = Key('ai-generated-content-indicator');
  static const _badgeKey = Key('ai-generated-content-badge');
  static const _iconSize = 15.0;
  static const _minimumWidth = _iconSize + 6 + 44;

  final VoidCallback? onReportPressed;
  final AlignmentGeometry iconAlignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: _iconSize,
          height: 44,
          child: Align(
            alignment: iconAlignment,
            child: const ExcludeSemantics(
              child: SizedBox.square(
                key: _badgeKey,
                dimension: _iconSize,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: _iconSize,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: _indicatorKey,
          tooltip: 'AI가 만든 내용 안내',
          onPressed: () => showAiGeneratedContentInfoSheet(
            context: context,
            onReportPressed: onReportPressed,
          ),
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          alignment: iconAlignment,
          visualDensity: VisualDensity.standard,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(44),
            maximumSize: const Size.square(44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const SizedBox.square(
            key: Key('ai-generated-content-info-icon'),
            dimension: _iconSize,
            child: Icon(Icons.info_rounded, size: 13, color: Color(0xCC6F737C)),
          ),
        ),
      ],
    );
  }
}

class AiGeneratedContent extends StatelessWidget {
  static const leadingExtent = 44.0 + 8.0;

  const AiGeneratedContent({
    super.key,
    required this.child,
    this.showIndicator = true,
    this.onReportPressed,
    this.indicator,
    this.heading,
    this.bodyAlignment = AlignmentDirectional.topStart,
  });

  final Widget child;
  final bool showIndicator;
  final VoidCallback? onReportPressed;
  final Widget? indicator;
  final Widget? heading;
  final AlignmentGeometry bodyAlignment;

  @override
  Widget build(BuildContext context) {
    if (!showIndicator) {
      return child;
    }

    final marker =
        indicator ??
        AiGeneratedContentIndicator(onReportPressed: onReportPressed);
    if (heading == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: AiGeneratedContentIndicator._minimumWidth,
        ),
        child: Stack(
          alignment: bodyAlignment,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 44,
              child: Align(alignment: Alignment.bottomLeft, child: marker),
            ),
            Padding(
              padding: const EdgeInsets.only(top: leadingExtent),
              child: child,
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            marker,
            if (heading case final heading?) Flexible(child: heading),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
