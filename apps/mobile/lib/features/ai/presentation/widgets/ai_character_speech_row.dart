import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/character_speech_bubble.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';

class AiCharacterSpeechRow extends StatelessWidget {
  const AiCharacterSpeechRow({
    super.key,
    required this.speechText,
    this.characterKey,
    this.bubbleKey,
    this.characterSize = 96,
    this.maximumContentWidth = 360,
    this.maxLines,
    this.semanticLabel,
  }) : _content = null;

  const AiCharacterSpeechRow.custom({
    super.key,
    required Widget child,
    required this.semanticLabel,
    this.characterKey,
    this.bubbleKey,
    this.characterSize = 96,
    this.maximumContentWidth = 360,
  }) : speechText = null,
       maxLines = null,
       _content = child;

  final String? speechText;
  final String? semanticLabel;
  final Key? characterKey;
  final Key? bubbleKey;
  final double characterSize;
  final double maximumContentWidth;
  final int? maxLines;
  final Widget? _content;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? speechText!;
    final bubble = _content == null
        ? CharacterSpeechBubble(
            key: bubbleKey,
            speechText: speechText!,
            maxWidth: double.infinity,
            maxLines: maxLines,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            tailSize: const Size(10, 18),
            tailPosition: SpeechBubbleTailPosition.left,
            textStyle: AppTextStyles.homeQuestionBubble,
          )
        : CharacterSpeechBubble.custom(
            key: bubbleKey,
            semanticLabel: label,
            maxWidth: double.infinity,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            tailSize: const Size(10, 18),
            tailPosition: SpeechBubbleTailPosition.left,
            child: _content,
          );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maximumContentWidth),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CoupleCharacterAvatar(key: characterKey, size: characterSize),
            Flexible(
              fit: FlexFit.loose,
              child: Semantics(
                label: label,
                excludeSemantics: true,
                child: bubble,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiCharacterSpeechColumn extends StatelessWidget {
  const AiCharacterSpeechColumn({
    super.key,
    required this.speechText,
    this.characterKey,
    this.bubbleKey,
    this.characterSize = 132,
    this.maximumBubbleWidth = 300,
    this.maxLines,
    this.semanticLabel,
  }) : _content = null;

  const AiCharacterSpeechColumn.custom({
    super.key,
    required Widget child,
    required this.semanticLabel,
    this.characterKey,
    this.bubbleKey,
    this.characterSize = 132,
    this.maximumBubbleWidth = 300,
  }) : speechText = null,
       maxLines = null,
       _content = child;

  final String? speechText;
  final String? semanticLabel;
  final Key? characterKey;
  final Key? bubbleKey;
  final double characterSize;
  final double maximumBubbleWidth;
  final int? maxLines;
  final Widget? _content;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? speechText!;
    final bubble = _content == null
        ? CharacterSpeechBubble(
            key: bubbleKey,
            speechText: speechText!,
            maxWidth: maximumBubbleWidth,
            maxLines: maxLines,
            tailPosition: SpeechBubbleTailPosition.bottom,
            textStyle: AppTextStyles.homeQuestionBubble,
          )
        : CharacterSpeechBubble.custom(
            key: bubbleKey,
            semanticLabel: label,
            maxWidth: maximumBubbleWidth,
            tailPosition: SpeechBubbleTailPosition.bottom,
            child: _content,
          );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(label: label, excludeSemantics: true, child: bubble),
          const SizedBox(height: 10),
          CoupleCharacterAvatar(key: characterKey, size: characterSize),
        ],
      ),
    );
  }
}

class AiCharacterThinkingSpeechRow extends StatelessWidget {
  const AiCharacterThinkingSpeechRow({
    super.key,
    required this.message,
    this.characterKey,
    this.bubbleKey,
    this.thinkingDotsKey,
    this.characterSize = 96,
    this.maximumContentWidth = 360,
  });

  final String message;
  final Key? characterKey;
  final Key? bubbleKey;
  final Key? thinkingDotsKey;
  final double characterSize;
  final double maximumContentWidth;

  @override
  Widget build(BuildContext context) {
    return AiCharacterSpeechRow.custom(
      semanticLabel: message,
      characterKey: characterKey,
      bubbleKey: bubbleKey,
      characterSize: characterSize,
      maximumContentWidth: maximumContentWidth,
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          WordBoundaryText(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeQuestionBubble,
          ),
          _ThinkingDots(key: thinkingDotsKey),
        ],
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({super.key});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  static const _dotCount = 3;
  static const _dotSize = 5.0;
  static const _duration = Duration(milliseconds: 1100);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 25,
      height: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_dotCount, (index) {
              final phase = (_controller.value - (index * 0.18)) % 1.0;
              final strength = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
              return Transform.translate(
                offset: Offset(0, -2 * strength),
                child: Opacity(
                  opacity: 0.3 + (0.7 * strength),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: _dotSize),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
