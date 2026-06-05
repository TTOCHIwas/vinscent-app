import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

const _speechBubbleColor = Color(0xFFEFEFEF);

class QuestionPromptCharacter extends StatelessWidget {
  const QuestionPromptCharacter({
    super.key,
    required this.questionText,
  });

  final String questionText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('질문', style: AppTextStyles.homeBodyMedium),
        const SizedBox(height: 20),
        _QuestionSpeechBubble(questionText: questionText),
        const SizedBox(height: 14),
        const CharacterPlaceholder(),
      ],
    );
  }
}

class CharacterPlaceholder extends StatelessWidget {
  const CharacterPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      color: AppColors.wireframePlaceholder,
      child: const Text(
        '캐릭터',
        style: AppTextStyles.homeCharacterLabel,
      ),
    );
  }
}

class _QuestionSpeechBubble extends StatelessWidget {
  const _QuestionSpeechBubble({required this.questionText});

  final String questionText;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _speechBubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            questionText,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              height: 1.4,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -1),
          child: CustomPaint(
            size: const Size(18, 10),
            painter: const _SpeechBubbleTailPainter(),
          ),
        ),
      ],
    );
  }
}

class _SpeechBubbleTailPainter extends CustomPainter {
  const _SpeechBubbleTailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _speechBubbleColor;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
