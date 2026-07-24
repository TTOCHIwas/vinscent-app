import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';

class QuestionDetailTitle extends StatelessWidget {
  const QuestionDetailTitle({super.key, required this.questionText});

  final String questionText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: '질문: $questionText',
      excludeSemantics: true,
      child: SizedBox(
        width: double.infinity,
        child: Text(
          questionText,
          key: const Key('question-detail-title'),
          textAlign: TextAlign.center,
          style: AppTypography.withFontSize(AppTextStyles.homeBodyMedium, 18),
        ),
      ),
    );
  }
}
