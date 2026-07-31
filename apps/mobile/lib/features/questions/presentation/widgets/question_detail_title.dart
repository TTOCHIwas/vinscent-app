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
  });

  final String questionText;
  final TextAlign textAlign;
  final bool showGeneratedIndicator;
  final VoidCallback? onGeneratedIndicatorPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AiGeneratedContentBadgeOverlay(
        showIndicator: showGeneratedIndicator,
        onReportPressed: onGeneratedIndicatorPressed,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: showGeneratedIndicator
                ? AiGeneratedContentBadgeOverlay.contentBottomPadding
                : 0,
          ),
          child: Semantics(
            header: true,
            label: showGeneratedIndicator
                ? 'AI 생성 질문: $questionText'
                : '질문: $questionText',
            excludeSemantics: true,
            child: WordBoundaryText(
              questionText,
              key: const Key('question-detail-title'),
              semanticsLabel: questionText,
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
