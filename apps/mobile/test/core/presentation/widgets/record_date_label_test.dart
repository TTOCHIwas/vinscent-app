import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/record_date_label.dart';
import 'package:vinscent/core/theme/app_theme.dart';

void main() {
  for (final (width, textScale, wraps) in [
    (560.0, 1.0, false),
    (240.0, 1.6, true),
  ]) {
    testWidgets(
      'date annotation adapts to width $width and text scale $textScale',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: RecordDateLabel(
                    date: DateTime(2026, 9, 14),
                    annotation: '둘이 가장 길게 답한 질문',
                  ),
                ),
              ),
            ),
          ),
        );
        final date = tester.getRect(find.text('9월 14일'));
        final annotation = tester.getRect(find.text('둘이 가장 길게 답한 질문'));
        final details = tester.getRect(find.text('2026 · 월요일'));
        if (wraps) {
          expect(annotation.top, greaterThanOrEqualTo(date.bottom));
        } else {
          expect(annotation.left, greaterThan(date.right));
          expect(annotation.center.dy, closeTo(date.center.dy, 0.01));
        }
        expect(details.top, greaterThanOrEqualTo(annotation.bottom));
        expect(
          annotation.right,
          lessThanOrEqualTo(tester.getRect(find.byType(RecordDateLabel)).right),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
