import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_theme.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_sections.dart';

void main() {
  for (final style in QuestionAnswerDisplayStyle.values) {
    for (final width in [240.0, 360.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '$style preserves body position with report at width $width scale $scale',
          (tester) async {
            const body = '함께 이야기를 나눴던 시간이 좋았어요. 다음에도 같이 쉬고 싶어요.';
            await _pumpSections(
              tester,
              style: style,
              width: width,
              scale: scale,
              body: body,
            );

            final own = find.byKey(const Key('own-answer'));
            final partner = find.byKey(const Key('partner-answer'));
            final ownTitle = tester.getRect(
              find.descendant(of: own, matching: find.text('내 답변')),
            );
            final partnerTitle = tester.getRect(
              find.descendant(of: partner, matching: find.text('상대방 답변')),
            );
            final bodyText = find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.data == body || widget.semanticsLabel == body),
            );
            final ownBody = tester.getRect(
              find.descendant(of: own, matching: bodyText),
            );
            final partnerBody = tester.getRect(
              find.descendant(of: partner, matching: bodyText),
            );
            final report = tester.getRect(
              find.byKey(const Key('partner-answer-report')),
            );

            expect(
              partnerBody.top - partnerTitle.bottom,
              closeTo(ownBody.top - ownTitle.bottom, 0.01),
            );
            expect(
              partnerBody.top - tester.getTopLeft(partner).dy,
              closeTo(ownBody.top - tester.getTopLeft(own).dy, 0.01),
            );
            expect(partnerBody.left, closeTo(ownBody.left, 0.01));
            expect(report.top, greaterThanOrEqualTo(partnerBody.top));
            expect(
              partnerBody.right + 8,
              lessThanOrEqualTo(report.left + 0.01),
            );
            expect(report.size, const Size.square(48));
            expect(
              tester
                  .getRect(partner)
                  .contains(report.bottomRight - const Offset(1, 1)),
              isTrue,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('$style keeps a short answer report target fully tappable', (
      tester,
    ) async {
      var reported = 0;
      await _pumpSections(
        tester,
        style: style,
        body: '고마워',
        onReportPressed: () => reported++,
      );

      final report = tester.getRect(
        find.byKey(const Key('partner-answer-report')),
      );
      await tester.tapAt(report.bottomRight - const Offset(3, 3));
      await tester.pump();

      expect(reported, 1);
      expect(find.byTooltip('상대방 답변 신고'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpSections(
  WidgetTester tester, {
  required QuestionAnswerDisplayStyle style,
  required String body,
  double width = 320,
  double scale = 1,
  VoidCallback? onReportPressed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  QuestionAnswerDisplaySection(
                    key: const Key('own-answer'),
                    title: '내 답변',
                    body: body,
                    isMuted: false,
                    displayStyle: style,
                  ),
                  const SizedBox(height: 28),
                  QuestionAnswerDisplaySection(
                    key: const Key('partner-answer'),
                    title: '상대방 답변',
                    body: body,
                    isMuted: false,
                    displayStyle: style,
                    onReportPressed: onReportPressed ?? () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
