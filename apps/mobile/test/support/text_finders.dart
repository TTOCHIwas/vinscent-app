import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Finder findTextIgnoringWordJoiners(String text) {
  String normalize(String value) => value
      .replaceAll('\u2060', '')
      .replaceAll('\uFFFC', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return find.byWidgetPredicate((widget) {
    if (widget is! Text) {
      return false;
    }

    if (widget.semanticsLabel == text) {
      return true;
    }

    final renderedText = widget.data ?? widget.textSpan?.toPlainText();
    return renderedText != null && normalize(renderedText) == normalize(text);
  });
}
