import 'package:flutter/material.dart';

final _hangulPattern = RegExp(r'[\u1100-\u11FF\u3130-\u318F\uAC00-\uD7A3]');
final _hardLineBreakPattern = RegExp(r'\r\n?|\n');
final _wordPattern = RegExp(r'\S+');

class WordBoundaryText extends StatelessWidget {
  const WordBoundaryText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.semanticsLabel,
    this.textAlign,
    this.trailing,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? semanticsLabel;
  final TextAlign? textAlign;
  final Widget? trailing;

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

        final trailing = this.trailing;
        if (trailing == null) {
          return Text(
            displayText,
            maxLines: maxLines,
            overflow: overflow,
            semanticsLabel: semanticsLabel ?? text,
            textAlign: textAlign,
            style: style,
          );
        }

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: displayText),
              const TextSpan(text: '\u2060'),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: trailing,
              ),
            ],
          ),
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

  if (!_hangulPattern.hasMatch(text)) {
    return text;
  }

  final measurer = _TextLineMeasurer(
    maxWidth: maxTextWidth,
    style: style,
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
  );

  try {
    if (!_hardLineBreakPattern.hasMatch(text) && measurer.fits(text)) {
      return text;
    }

    return text
        .split(_hardLineBreakPattern)
        .expand((line) => _wrapLineByWords(line, measurer))
        .join('\n');
  } finally {
    measurer.dispose();
  }
}

Iterable<String> _wrapLineByWords(
  String line,
  _TextLineMeasurer measurer,
) sync* {
  if (line.isEmpty || measurer.fits(line)) {
    yield line;
    return;
  }

  final matches = _wordPattern.allMatches(line).toList(growable: false);
  if (matches.isEmpty) {
    yield line;
    return;
  }

  var currentLine = '';
  var previousEnd = 0;

  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final word = match.group(0)!;
    final whitespace = line.substring(previousEnd, match.start);
    final candidate = currentLine.isEmpty
        ? index == 0
              ? '$whitespace$word'
              : word
        : '$currentLine$whitespace$word';

    if (measurer.fits(candidate)) {
      currentLine = candidate;
      previousEnd = match.end;
      continue;
    }

    if (currentLine.isNotEmpty) {
      yield currentLine;
    }

    final segments = _splitOversizedWord(word, measurer);
    for (
      var segmentIndex = 0;
      segmentIndex < segments.length - 1;
      segmentIndex++
    ) {
      yield segments[segmentIndex];
    }
    currentLine = segments.last;
    previousEnd = match.end;
  }

  final trailingWhitespace = line.substring(previousEnd);
  if (currentLine.isNotEmpty) {
    final candidate = '$currentLine$trailingWhitespace';
    yield measurer.fits(candidate) ? candidate : currentLine;
  } else if (trailingWhitespace.isNotEmpty) {
    yield trailingWhitespace;
  }
}

List<String> _splitOversizedWord(String word, _TextLineMeasurer measurer) {
  if (measurer.fits(word)) {
    return [word];
  }

  final segments = <String>[];
  var currentSegment = '';

  for (final character in word.characters) {
    final candidate = '$currentSegment$character';
    if (currentSegment.isNotEmpty && !measurer.fits(candidate)) {
      segments.add(currentSegment);
      currentSegment = character;
      continue;
    }
    currentSegment = candidate;
  }

  if (currentSegment.isNotEmpty) {
    segments.add(currentSegment);
  }
  return segments;
}

class _TextLineMeasurer {
  _TextLineMeasurer({
    required this.maxWidth,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required Locale? locale,
  }) : _painter = TextPainter(
         text: TextSpan(style: style),
         textDirection: textDirection,
         textScaler: textScaler,
         locale: locale,
         maxLines: 1,
       );

  final double maxWidth;
  final TextPainter _painter;

  bool fits(String text) {
    _painter.text = TextSpan(text: text, style: _painter.text?.style);
    _painter.layout();
    return _painter.width <= maxWidth + 0.01;
  }

  void dispose() {
    _painter.dispose();
  }
}
