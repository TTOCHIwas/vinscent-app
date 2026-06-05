import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

const _speechBubbleColor = Color(0xFFEFEFEF);

class CharacterSpeechPrompt extends StatelessWidget {
  const CharacterSpeechPrompt({
    super.key,
    required this.labelText,
    required this.speechText,
    this.characterLabel = '캐릭터',
    this.maxSpeechWidth = 300,
  });

  final String labelText;
  final String speechText;
  final String characterLabel;
  final double maxSpeechWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(labelText, style: AppTextStyles.homeBodyMedium),
        const SizedBox(height: 20),
        _SpeechBubble(
          speechText: speechText,
          maxWidth: maxSpeechWidth,
        ),
        const SizedBox(height: 14),
        CharacterPlaceholder(label: characterLabel),
      ],
    );
  }
}

class CharacterPlaceholder extends StatelessWidget {
  const CharacterPlaceholder({
    super.key,
    this.label = '캐릭터',
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      alignment: Alignment.center,
      color: AppColors.wireframePlaceholder,
      child: Text(label, style: AppTextStyles.homeCharacterLabel),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({
    required this.speechText,
    required this.maxWidth,
  });

  final String speechText;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _speechBubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            speechText,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(height: 1.4),
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
