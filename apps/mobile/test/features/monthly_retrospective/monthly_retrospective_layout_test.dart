import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_page_header.dart';
import 'package:vinscent/core/theme/app_theme.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_sections.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_controller.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective_repository.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/monthly_retrospective_screen.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/widgets/monthly_card_scatter.dart';
import 'package:vinscent/features/shell/presentation/app_shell.dart';

void main() {
  for (final aiEntry in [false, true]) {
    testWidgets(
      'ordinary recap pages fit the shell without vertical scrolling, AI entry: $aiEntry',
      (tester) async {
        await _pump(tester, aiEntry: aiEntry);
        expect(find.text('월간 회고'), findsNothing);
        final header = tester.getRect(find.byType(AppPageHeader));
        expect(header.height, 56);
        if (!aiEntry) {
          expect(header.top, 56);
          expect(
            tester.getCenter(find.byTooltip('캘린더로 돌아가기')),
            const Offset(44, 84),
          );
        }
        final pages = ['지난달 이야기', '그날의 기억', '우리의 답', '마음 남기기'];
        for (var i = 0; i < pages.length; i++) {
          await tester.tap(find.byKey(Key('monthly-page-indicator-$i')));
          await tester.pumpAndSettle();
          expect(
            _position(tester, pages[i]).maxScrollExtent,
            closeTo(0, 0.01),
            reason: pages[i],
          );
        }
        await tester.tap(find.byKey(const Key('monthly-page-indicator-1')));
        await tester.pumpAndSettle();
        final moment = find.byKey(
          ValueKey('monthly-moment-${DateTime(2026, 9, 5)}'),
        );
        final cards = tester.getRect(
          find.descendant(
            of: moment,
            matching: find.byType(MonthlyCardScatter),
          ),
        );
        final question = tester.getRect(find.text('오늘 가장 기억에 남는 순간은?'));
        expect(cards.right, lessThan(question.left));
        expect(cards.top, lessThan(question.bottom));
        expect(cards.bottom, greaterThan(question.top));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'long original answers remain readable through overflow scrolling',
    (tester) async {
      await _pump(tester, longAnswers: true);
      await tester.tap(find.byKey(const Key('monthly-page-indicator-2')));
      await tester.pumpAndSettle();
      expect(_position(tester, '우리의 답').maxScrollExtent, greaterThan(0));
      final text = _answer(true);
      final answers = tester.widgetList<QuestionAnswerDisplaySection>(
        find.byType(QuestionAnswerDisplaySection),
      );
      expect(answers.where((answer) => answer.body == text), hasLength(2));
      await tester.drag(
        find.byKey(PageStorageKey('${DateTime(2026, 9)}:우리의 답')),
        const Offset(0, -10000),
      );
      await tester.pumpAndSettle();
      expect(_position(tester, '우리의 답').pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large text and keyboard keep reflection input and save action reachable',
    (tester) async {
      await _pump(tester, textScale: 1.6, keyboardHeight: 300);
      await tester.tap(find.byKey(const Key('monthly-page-indicator-3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '다음 달에도 함께 산책하기');
      await tester.ensureVisible(find.widgetWithText(FilledButton, '마음 남기기'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, '마음 남기기').hitTestable(),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '다음 달에도 함께 산책하기',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

ScrollPosition _position(WidgetTester tester, String page) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(PageStorageKey('${DateTime(2026, 9)}:$page')),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<void> _pump(
  WidgetTester tester, {
  bool aiEntry = false,
  bool longAnswers = false,
  double textScale = 1,
  double keyboardHeight = 0,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        monthlyRetrospectiveControllerProvider.overrideWithBuild(
          (ref, notifier) async => _fixture(longAnswers),
        ),
        monthlyRetrospectiveRepositoryProvider.overrideWithValue(_Repository()),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            viewInsets: EdgeInsets.only(bottom: keyboardHeight),
          ),
          child: child!,
        ),
        home: AppShell(
          location: aiEntry ? '/ai' : '/calendar/monthly',
          child: Column(
            children: [
              if (aiEntry) const SizedBox(height: 64),
              Expanded(
                child: MonthlyRetrospectiveScreen(
                  onBack: aiEntry ? null : () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _answer(bool long) => long
    ? List.filled(80, '같이 커피 마시면서 하루 이야기를 나눴어.').join('\n')
    : '같이 커피 마시며 하루 이야기를 나눈 시간.';

Map<String, Object?> _card(int i) => {
  'id': 'c$i',
  'date': '2026-09-${(i + 1).toString().padLeft(2, '0')}',
  'author_user_id': i.isEven ? 'a' : 'b',
  'preview_path': 'preview-$i',
  'aspect_ratio': 0.8,
  'card_type': 'polaroid',
  'layout_version': 2,
};

MonthlyRetrospective _fixture(bool long) => MonthlyRetrospective.fromJson({
  'couple_id': 'c',
  'month': '2026-09-01',
  'available_until': '2026-11-01T00:00:00Z',
  'recorded_days': 12,
  'card_count': 18,
  'card_count_complete': true,
  'completed_questions': 8,
  'has_records': true,
  'ai_enabled': true,
  'title': '평범한 하루에 남긴 우리의 9월',
  'summary': '서로의 할 일을 응원하고, 커피를 마시며 쉬었던 이야기를 남겼어. 다음 달에도 함께 산책하고 싶다고 적었어.',
  'content_status': 'ready',
  'gallery': [for (var i = 0; i < 24; i++) _card(i)],
  'moments': [
    for (final entry in [
      (5, '오늘 가장 기억에 남는 순간은?'),
      (14, '이번 주 서로에게 고마웠던 일은?'),
      (27, '다시 함께하고 싶은 일은?'),
    ])
      {
        'date': '2026-09-${entry.$1.toString().padLeft(2, '0')}',
        'question': entry.$2,
        'cards': [_card(0), _card(1)],
      },
  ],
  'conversation': {
    'date': '2026-09-14',
    'question': '다시 함께하고 싶은 순간은?',
    'my_answer': _answer(long),
    'partner_answer': _answer(long),
    'partner_answer_id': 'a2',
  },
  'reflection': {
    'id': 'r',
    'question': '다음 달 함께 이어가고 싶은 일상은 뭐야?',
    'source': 'ai',
    'my_answer': null,
    'partner_answer': null,
    'partner_answer_exists': false,
    'version': 0,
  },
});

class _Repository implements MonthlyRetrospectiveRepository {
  @override
  Future<Map<String, String>> previewUrls(
    Iterable<RetrospectiveCard> cards,
  ) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
