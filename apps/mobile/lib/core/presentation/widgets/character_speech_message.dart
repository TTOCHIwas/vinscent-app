import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';
import 'word_boundary_text.dart';

class CharacterSpeechMessage extends StatelessWidget {
  const CharacterSpeechMessage({
    super.key,
    required this.speechText,
    this.maxWidth = 300,
    this.maxLines,
    this.textStyle = AppTextStyles.homeCharacterLabel,
    this.textAlign = TextAlign.start,
  }) : semanticLabel = speechText,
       _content = null;

  const CharacterSpeechMessage.custom({
    super.key,
    required Widget child,
    required this.semanticLabel,
    this.maxWidth = 300,
  }) : speechText = semanticLabel,
       maxLines = null,
       textStyle = AppTextStyles.homeCharacterLabel,
       textAlign = TextAlign.start,
       _content = child;

  final String speechText;
  final String semanticLabel;
  final double maxWidth;
  final int? maxLines;
  final TextStyle textStyle;
  final TextAlign textAlign;
  final Widget? _content;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final effectiveMaxLines = textScaler.scale(1) > 1.01 ? null : maxLines;
        final maximumWidth = constraints.hasBoundedWidth
            ? math.min(maxWidth, constraints.maxWidth)
            : maxWidth;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maximumWidth),
          child: _content == null
              ? WordBoundaryText(
                  speechText,
                  maxLines: effectiveMaxLines,
                  overflow: effectiveMaxLines == null
                      ? null
                      : TextOverflow.ellipsis,
                  semanticsLabel: semanticLabel,
                  textAlign: textAlign,
                  style: textStyle,
                )
              : Semantics(
                  label: semanticLabel,
                  excludeSemantics: true,
                  child: _content,
                ),
        );
      },
    );
  }
}
