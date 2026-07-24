import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_text_styles.dart';

class AiTabHeader extends StatelessWidget {
  const AiTabHeader({super.key});

  static const minHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('ai-tab-header'),
      constraints: const BoxConstraints(minHeight: minHeight),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Center(
          child: WordBoundaryText(
            '우리 둘의 AI',
            textAlign: TextAlign.center,
            style: AppTextStyles.pageTitle,
          ),
        ),
      ),
    );
  }
}
