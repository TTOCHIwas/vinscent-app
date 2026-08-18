import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/character_speech_message.dart';
import '../../../../core/presentation/widgets/character_speech_row.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';
import 'ai_generated_content_indicator.dart';

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
    this.textAlign = TextAlign.start,
    this.showGeneratedIndicator = false,
    this.onGeneratedIndicatorPressed,
  }) : _content = null;

  const AiCharacterSpeechRow.custom({
    super.key,
    required Widget child,
    required this.semanticLabel,
    this.characterKey,
    this.bubbleKey,
    this.characterSize = 96,
    this.maximumContentWidth = 360,
    this.showGeneratedIndicator = false,
    this.onGeneratedIndicatorPressed,
  }) : speechText = null,
       maxLines = null,
       textAlign = TextAlign.start,
       _content = child;

  final String? speechText;
  final String? semanticLabel;
  final Key? characterKey;
  final Key? bubbleKey;
  final double characterSize;
  final double maximumContentWidth;
  final int? maxLines;
  final Widget? _content;
  final TextAlign textAlign;
  final bool showGeneratedIndicator;
  final VoidCallback? onGeneratedIndicatorPressed;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? speechText!;
    final message = _content == null
        ? CharacterSpeechMessage(
            key: bubbleKey,
            speechText: speechText!,
            maxWidth: double.infinity,
            maxLines: maxLines,
            textStyle: AppTextStyles.homeQuestionBubble,
            textAlign: textAlign,
          )
        : CharacterSpeechMessage.custom(
            key: bubbleKey,
            semanticLabel: label,
            maxWidth: double.infinity,
            child: _content,
          );
    final presentedMessage = AiGeneratedContentBadgeOverlay(
      showIndicator: showGeneratedIndicator,
      onReportPressed: onGeneratedIndicatorPressed,
      reserveIndicatorSpace: true,
      child: Semantics(label: label, excludeSemantics: true, child: message),
    );

    return CharacterSpeechRow(
      maximumContentWidth: maximumContentWidth,
      character: CoupleCharacterAvatar(key: characterKey, size: characterSize),
      message: presentedMessage,
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
    this.maximumBubbleWidth = double.infinity,
    this.maxLines,
    this.semanticLabel,
    this.textAlign = TextAlign.start,
    this.showGeneratedIndicator = false,
    this.attachGeneratedIndicatorToText = false,
    this.onGeneratedIndicatorPressed,
  }) : _content = null;

  const AiCharacterSpeechColumn.custom({
    super.key,
    required Widget child,
    required this.semanticLabel,
    this.characterKey,
    this.bubbleKey,
    this.characterSize = 132,
    this.maximumBubbleWidth = double.infinity,
    this.showGeneratedIndicator = false,
    this.onGeneratedIndicatorPressed,
  }) : speechText = null,
       maxLines = null,
       textAlign = TextAlign.start,
       attachGeneratedIndicatorToText = false,
       _content = child;

  final String? speechText;
  final String? semanticLabel;
  final Key? characterKey;
  final Key? bubbleKey;
  final double characterSize;
  final double maximumBubbleWidth;
  final int? maxLines;
  final Widget? _content;
  final TextAlign textAlign;
  final bool showGeneratedIndicator;
  final bool attachGeneratedIndicatorToText;
  final VoidCallback? onGeneratedIndicatorPressed;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? speechText!;
    final attachesIndicator =
        _content == null &&
        showGeneratedIndicator &&
        attachGeneratedIndicatorToText;
    final message = _content == null
        ? CharacterSpeechMessage(
            key: bubbleKey,
            speechText: speechText!,
            semanticLabel: label,
            maxWidth: maximumBubbleWidth,
            maxLines: maxLines,
            textStyle: AppTextStyles.homeQuestionBubble,
            textAlign: textAlign,
            trailing: attachesIndicator
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(start: 2),
                    child: AiGeneratedContentIndicator(
                      onReportPressed: onGeneratedIndicatorPressed,
                    ),
                  )
                : null,
          )
        : CharacterSpeechMessage.custom(
            key: bubbleKey,
            semanticLabel: label,
            maxWidth: maximumBubbleWidth,
            child: _content,
          );
    final presentedMessage = attachesIndicator
        ? message
        : AiGeneratedContentBadgeOverlay(
            showIndicator: showGeneratedIndicator,
            onReportPressed: onGeneratedIndicatorPressed,
            attachmentBottomInset: 10,
            reserveIndicatorSpace: true,
            child: Semantics(
              label: label,
              excludeSemantics: true,
              child: message,
            ),
          );

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          presentedMessage,
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            child: CoupleCharacterAvatar(
              key: characterKey,
              size: characterSize,
            ),
          ),
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
      child: _ThinkingSpeechContent(
        message: message,
        thinkingDotsKey: thinkingDotsKey,
      ),
    );
  }
}

class AiCharacterThinkingSpeechColumn extends StatelessWidget {
  const AiCharacterThinkingSpeechColumn({
    super.key,
    required this.message,
    this.characterKey,
    this.bubbleKey,
    this.thinkingDotsKey,
    this.characterSize = 132,
    this.maximumBubbleWidth = double.infinity,
  });

  final String message;
  final Key? characterKey;
  final Key? bubbleKey;
  final Key? thinkingDotsKey;
  final double characterSize;
  final double maximumBubbleWidth;

  @override
  Widget build(BuildContext context) {
    return AiCharacterSpeechColumn.custom(
      semanticLabel: message,
      characterKey: characterKey,
      bubbleKey: bubbleKey,
      characterSize: characterSize,
      maximumBubbleWidth: maximumBubbleWidth,
      child: _ThinkingSpeechContent(
        message: message,
        thinkingDotsKey: thinkingDotsKey,
      ),
    );
  }
}

class _ThinkingSpeechContent extends StatelessWidget {
  const _ThinkingSpeechContent({
    required this.message,
    required this.thinkingDotsKey,
  });

  final String message;
  final Key? thinkingDotsKey;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
