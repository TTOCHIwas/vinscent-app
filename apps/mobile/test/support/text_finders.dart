import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Finder findTextIgnoringWordJoiners(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) {
      return false;
    }

    final renderedText = widget.data ?? widget.textSpan?.toPlainText();
    return renderedText?.replaceAll('\u2060', '') == text;
  });
}
