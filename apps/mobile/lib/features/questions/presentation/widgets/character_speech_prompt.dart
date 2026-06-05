import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';

const _speechBubbleColor = Color(0xFFEFEFEF);

class CharacterSpeechPrompt extends StatelessWidget {
  const CharacterSpeechPrompt({
    super.key,
    required this.labelText,
    required this.speechText,
    this.characterLabel = '캐릭터',
    this.maxSpeechWidth = 300,
    this.onSpeechTap,
    this.onCharacterTap,
  });

  final String labelText;
  final String speechText;
  final String characterLabel;
  final double maxSpeechWidth;
  final VoidCallback? onSpeechTap;
  final VoidCallback? onCharacterTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(labelText, style: AppTextStyles.homeBodyMedium),
        const SizedBox(height: 20),
        _OptionalTap(
          onTap: onSpeechTap,
          borderRadius: BorderRadius.circular(12),
          child: _SpeechBubble(
            speechText: speechText,
            maxWidth: maxSpeechWidth,
          ),
        ),
        const SizedBox(height: 14),
        CoupleCharacterAvatar(label: characterLabel, onTap: onCharacterTap),
      ],
    );
  }
}

class _OptionalTap extends StatelessWidget {
  const _OptionalTap({
    required this.child,
    required this.borderRadius,
    this.onTap,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: child),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.speechText, required this.maxWidth});

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
