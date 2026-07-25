import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';

void main() {
  const style = TextStyle(fontSize: 16, letterSpacing: -0.4);
  const locale = Locale('ko');

  test('keeps a fitting Korean sentence unchanged', () {
    const text = '같이 쉬는 시간을 좋아해';
    final result = keepWordsTogether(
      text,
      maxTextWidth: _textWidth(text, style: style, locale: locale) + 1,
      style: style,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: locale,
    );

    expect(result, text);
    expect(result, isNot(contains('\u2060')));
  });

  test('wraps Korean text at a space before splitting a word', () {
    const firstWord = '가나다';
    const secondWord = '라마바사';
    const text = '$firstWord $secondWord';
    final maxTextWidth =
        math.max(
          _textWidth(firstWord, style: style, locale: locale),
          _textWidth(secondWord, style: style, locale: locale),
        ) +
        1;

    final result = keepWordsTogether(
      text,
      maxTextWidth: maxTextWidth,
      style: style,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: locale,
    );

    expect(result, '$firstWord\n$secondWord');
    expect(result, isNot(contains('\u2060')));
  });

  test('splits only an oversized word at grapheme boundaries', () {
    const text = '가나다라마바사';
    final maxTextWidth = _textWidth('가나', style: style, locale: locale) + 1;

    final result = keepWordsTogether(
      text,
      maxTextWidth: maxTextWidth,
      style: style,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
      locale: locale,
    );

    expect(result, '가나\n다라\n마바\n사');
  });

  testWidgets('preserves text presentation and accessibility contracts', (
    tester,
  ) async {
    const text = '첫 번째 질문에 대한 조금 긴 답변';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            child: WordBoundaryText(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ),
      ),
    );

    final rendered = tester.widget<Text>(
      find.descendant(
        of: find.byType(WordBoundaryText),
        matching: find.byType(Text),
      ),
    );

    expect(rendered.data, isNot(contains('\u2060')));
    expect(rendered.maxLines, 2);
    expect(rendered.overflow, TextOverflow.ellipsis);
    expect(rendered.textAlign, TextAlign.center);
    expect(rendered.style?.letterSpacing, -0.4);
    expect(rendered.semanticsLabel, text);
  });
}

double _textWidth(
  String text, {
  required TextStyle style,
  required Locale locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
    locale: locale,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}
