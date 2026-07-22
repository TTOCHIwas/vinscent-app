import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';
import 'word_boundary_text.dart';

const _speechBubbleColor = Color(0xFFEFEFEF);

enum SpeechBubbleTailPosition { bottom, left }

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
  }) : semanticLabel = speechText,
       _content = null;

  const CharacterSpeechBubble.custom({
    super.key,
    required Widget child,
    required this.semanticLabel,
    this.maxWidth = 300,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 12,
    ),
    this.tailSize = const Size(18, 10),
    this.tailPosition = SpeechBubbleTailPosition.bottom,
  }) : speechText = semanticLabel,
       maxLines = null,
       textStyle = AppTextStyles.homeCharacterLabel,
       _content = child;

  final String speechText;
  final String semanticLabel;
  final double maxWidth;
  final int? maxLines;
  final EdgeInsetsGeometry contentPadding;
  final Size tailSize;
  final SpeechBubbleTailPosition tailPosition;
  final TextStyle textStyle;
  final Widget? _content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final effectiveMaxLines = textScaler.scale(1) > 1.01 ? null : maxLines;
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
        final bubbleMaxWidth = math.min(maxWidth, maxContentWidth);
        final bubble = Container(
          constraints: BoxConstraints(
            maxWidth: bubbleMaxWidth,
            maxHeight: maxContentHeight,
          ),
          padding: contentPadding,
          decoration: BoxDecoration(
            color: _speechBubbleColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _content == null
              ? WordBoundaryText(
                  speechText,
                  maxLines: effectiveMaxLines,
                  overflow: effectiveMaxLines == null
                      ? null
                      : TextOverflow.ellipsis,
                  semanticsLabel: semanticLabel,
                  textAlign: TextAlign.center,
                  style: textStyle,
                )
              : Semantics(
                  label: semanticLabel,
                  excludeSemantics: true,
                  child: _content,
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
