import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/character_speech_bubble.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';

export '../../../../core/presentation/widgets/character_speech_bubble.dart';

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
          child: CharacterSpeechBubble(
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
