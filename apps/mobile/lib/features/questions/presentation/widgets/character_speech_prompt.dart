import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';

const _speechBubbleColor = Color(0xFFEFEFEF);

enum SpeechBubbleTailPosition { bottom, left }

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

class CharacterSpeechBubble extends StatelessWidget {
  const CharacterSpeechBubble({
    super.key,
    required this.speechText,
    this.maxWidth = 300,
    this.maxLines,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 12,
    ),
    this.tailSize = const Size(18, 10),
    this.tailPosition = SpeechBubbleTailPosition.bottom,
    this.textStyle = AppTextStyles.homeCharacterLabel,
  });

  final String speechText;
  final double maxWidth;
  final int? maxLines;
  final EdgeInsetsGeometry contentPadding;
  final Size tailSize;
  final SpeechBubbleTailPosition tailPosition;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tailWidth = tailPosition == SpeechBubbleTailPosition.left
            ? tailSize.width
            : 0.0;
        final tailHeight = tailPosition == SpeechBubbleTailPosition.bottom
            ? tailSize.height
            : 0.0;
        final maxContentWidth = constraints.hasBoundedWidth
            ? math.max(0.0, constraints.maxWidth - tailWidth)
            : double.infinity;
        final maxContentHeight = constraints.hasBoundedHeight
            ? math.max(0.0, constraints.maxHeight - tailHeight)
            : double.infinity;
        final bubble = Container(
          constraints: BoxConstraints(
            maxWidth: math.min(maxWidth, maxContentWidth),
            maxHeight: maxContentHeight,
          ),
          padding: contentPadding,
          decoration: BoxDecoration(
            color: _speechBubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            speechText,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        );

        if (tailPosition == SpeechBubbleTailPosition.left) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.translate(
                offset: const Offset(1, 0),
                child: CustomPaint(
                  size: tailSize,
                  painter: const _SpeechBubbleTailPainter(
                    position: SpeechBubbleTailPosition.left,
                  ),
                ),
              ),
              bubble,
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bubble,
            Transform.translate(
              offset: const Offset(0, -1),
              child: CustomPaint(
                size: tailSize,
                painter: const _SpeechBubbleTailPainter(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpeechBubbleTailPainter extends CustomPainter {
  const _SpeechBubbleTailPainter({
    this.position = SpeechBubbleTailPosition.bottom,
  });

  final SpeechBubbleTailPosition position;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _speechBubbleColor;
    final path = switch (position) {
      SpeechBubbleTailPosition.bottom =>
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(size.width, 0)
          ..close(),
      SpeechBubbleTailPosition.left =>
        Path()
          ..moveTo(size.width, 0)
          ..lineTo(0, size.height / 2)
          ..lineTo(size.width, size.height)
          ..close(),
    };

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SpeechBubbleTailPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}
