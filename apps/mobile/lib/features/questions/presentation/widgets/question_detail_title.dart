import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';

class QuestionDetailTitle extends StatelessWidget {
  const QuestionDetailTitle({
    super.key,
    required this.questionText,
    this.textAlign = TextAlign.center,
  });

  final String questionText;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '질문: $questionText',
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: WordBoundaryText(
          questionText,
          key: const Key('question-detail-title'),
          semanticsLabel: questionText,
          textAlign: textAlign,
          style: AppTypography.withFontSize(AppTextStyles.homeBodyMedium, 18),
        ),
      ),
    );
  }
}
