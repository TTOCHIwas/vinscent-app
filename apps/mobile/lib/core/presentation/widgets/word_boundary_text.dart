import 'package:flutter/material.dart';

const _wordJoiner = '\u2060';
final _hangulPattern = RegExp(r'[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7A3]');
final _whitespacePattern = RegExp(r'\s+');

class WordBoundaryText extends StatelessWidget {
  const WordBoundaryText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.semanticsLabel,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? semanticsLabel;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
        final displayText = keepWordsTogether(
          text,
          maxTextWidth: constraints.maxWidth,
          style: resolvedStyle,
          textDirection: textDirection,
          textScaler: MediaQuery.textScalerOf(context),
          locale: Localizations.maybeLocaleOf(context),
        );

        return Text(
          displayText,
          maxLines: maxLines,
          overflow: overflow,
          semanticsLabel: semanticsLabel ?? text,
          textAlign: textAlign,
          style: style,
        );
      },
    );
  }
}

String keepWordsTogether(
  String text, {
  required double maxTextWidth,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
}) {
  if (text.isEmpty || maxTextWidth <= 0 || !maxTextWidth.isFinite) {
    return text;
  }

  return text.splitMapJoin(
    _whitespacePattern,
    onMatch: (match) => match.group(0)!,
    onNonMatch: (word) {
      if (!_hangulPattern.hasMatch(word) ||
          word.characters.length < 2 ||
          !_fitsOnOneLine(
            word,
            maxWidth: maxTextWidth,
            style: style,
            textDirection: textDirection,
            textScaler: textScaler,
            locale: locale,
          )) {
        return word;
      }

      return word.characters.join(_wordJoiner);
    },
  );
}

bool _fitsOnOneLine(
  String text, {
  required double maxWidth,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: 1,
  )..layout();
  final fits = painter.width <= maxWidth;
  painter.dispose();
  return fits;
}
