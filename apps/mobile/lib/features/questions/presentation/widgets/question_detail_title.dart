import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../ai/presentation/widgets/ai_generated_content_indicator.dart';

class QuestionDetailTitle extends StatelessWidget {
  const QuestionDetailTitle({
    super.key,
    required this.questionText,
    this.textAlign = TextAlign.center,
    this.showGeneratedIndicator = false,
    this.onGeneratedIndicatorPressed,
    this.semanticsLabel,
  });

  final String questionText;
  final TextAlign textAlign;
  final bool showGeneratedIndicator;
  final VoidCallback? onGeneratedIndicatorPressed;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: AiGeneratedContent(
          bodyAlignment: textAlign == TextAlign.center
              ? Alignment.topCenter
              : AlignmentDirectional.topStart,
          showIndicator: showGeneratedIndicator,
          onReportPressed: onGeneratedIndicatorPressed,
          child: Semantics(
            header: true,
            child: WordBoundaryText(
              questionText,
              key: const Key('question-detail-title'),
              semanticsLabel:
                  semanticsLabel ??
                  (showGeneratedIndicator
                      ? 'AI 생성 질문: $questionText'
                      : questionText),
              textAlign: textAlign,
              style: AppTypography.withFontSize(
                AppTextStyles.homeBodyMedium,
                18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
