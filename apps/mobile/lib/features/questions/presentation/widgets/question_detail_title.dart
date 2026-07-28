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
  });

  final String questionText;
  final TextAlign textAlign;
  final bool showGeneratedIndicator;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: showGeneratedIndicator
          ? 'AI 생성 질문: $questionText'
          : '질문: $questionText',
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WordBoundaryText(
              questionText,
              key: const Key('question-detail-title'),
              semanticsLabel: questionText,
              textAlign: textAlign,
              style: AppTypography.withFontSize(
                AppTextStyles.homeBodyMedium,
                18,
              ),
            ),
            if (showGeneratedIndicator)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: switch (textAlign) {
                    TextAlign.center => Alignment.center,
                    TextAlign.right ||
                    TextAlign.end => AlignmentDirectional.centerEnd,
                    _ => AlignmentDirectional.centerStart,
                  },
                  child: const AiGeneratedContentIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
