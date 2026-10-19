import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_page_header.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_message.dart';
import 'package:vinscent/core/presentation/widgets/record_date_label.dart';
import 'package:vinscent/core/theme/app_text_styles.dart';
import 'package:vinscent/core/theme/app_theme.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_character_speech_row.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_generated_content_indicator.dart';
import 'package:vinscent/features/characters/presentation/widgets/couple_character_avatar.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_sections.dart';
import 'package:vinscent/features/monthly_retrospective/application/monthly_retrospective_controller.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective_repository.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/monthly_retrospective_screen.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/widgets/monthly_card_scatter.dart';
import 'package:vinscent/features/monthly_retrospective/presentation/widgets/monthly_retrospective_section.dart';
import 'package:vinscent/features/shell/presentation/app_shell.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_bottom_bar.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('one vertical recap keeps its header fixed at width $width', (
      tester,
    ) async {
      await _pump(tester, width: width);
      expect(find.byType(PageView), findsNothing);
      expect(find.byKey(const Key('monthly-page-control')), findsNothing);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      final header = tester.getRect(find.byType(AppPageHeader));
      expect(header.height, 56);
      expect(header.top, 56);
      expect(tester.getCenter(find.byTooltip('뒤로가기')), const Offset(44, 84));
      expect(
        tester.widget<Text>(find.text('2026년 09월')).style,
        AppTextStyles.pageTitle,
      );
      expect(
        tester.getCenter(find.text('2026년 09월')).dx,
        closeTo(width / 2, 0.01),
      );
      final information = tester.getRect(
        find.byKey(const Key('monthly-overview-information')),
      );
      final overview = tester.getRect(
        find.byKey(const Key('monthly-overview')),
      );
      final conversation = tester.getRect(
        find.byKey(const Key('monthly-conversation')),
      );
      final memories = tester.getRect(
        find.byKey(const Key('monthly-memories')),
      );
      final reflection = tester.getRect(
        find.byKey(const Key('monthly-reflection')),
      );
      expect(
        information.bottom,
        closeTo(tester.getRect(find.byType(AppBottomBar)).top - 12, 0.01),
      );
      _expectBalancedPile(tester);
      expect(conversation.top - overview.bottom, closeTo(64, 0.01));
      expect(memories.top - conversation.bottom, closeTo(64, 0.01));
      expect(reflection.top - memories.bottom, closeTo(64, 0.01));
      final sectionHeaders = tester
          .widgetList<MonthlySectionHeader>(find.byType(MonthlySectionHeader))
          .toList();
      expect(sectionHeaders.map((header) => header.title), [
        '그날의 기억',
        '마음 남기기',
      ]);
      expect(sectionHeaders.map((header) => header.description), [
        '사진이 남아 있는 날 중 최대 세 날의 기록을 골랐어요.',
        '같은 질문에 각자의 답을 남기며 한 달을 마무리해요.',
      ]);
      expect(find.text('지난달 우리 이야기'), findsNothing);
      expect(find.text('우리의 답'), findsNothing);
      final contentTitle = tester.getRect(
        find.byKey(const Key('monthly-overview-title')),
      );
      final statistics = tester.getRect(
        find.byKey(const Key('monthly-overview-statistics')),
      );
      final summary = tester.getRect(
        find.byKey(const Key('monthly-overview-summary')),
      );
      expect(statistics.top - contentTitle.bottom, closeTo(24, 0.01));
      expect(summary.top - statistics.bottom, closeTo(32, 0.01));
      expect(
        tester
            .widget<Text>(find.byKey(const Key('monthly-overview-title')))
            .style,
        AppTextStyles.contentTitle,
      );
      expect(
        tester.widget<Text>(find.text('18개')).style,
        AppTextStyles.pageTitle,
      );
      expect(tester.widget<Text>(find.text('남긴 카드')).style?.fontSize, 14);
      expect(
        tester.widget<Text>(find.text('그날의 기억')).style,
        AppTextStyles.sectionTitle,
      );
      expect(
        tester.widget<Text>(find.text('둘이 가장 길게 답한 질문')).style?.fontSize,
        14,
      );
      expect(
        tester.widget<RecordDateLabel>(find.byType(RecordDateLabel)).date,
        DateTime(2026, 9, 14),
      );
      expect(find.text('2026 · 월요일'), findsOneWidget);
      expect(
        tester.widget<RecordDateLabel>(find.byType(RecordDateLabel)).annotation,
        '둘이 가장 길게 답한 질문',
      );
      for (final row in tester.widgetList<AiCharacterSpeechRow>(
        find.byType(AiCharacterSpeechRow),
      )) {
        expect(row.characterSize, 96);
      }
      final avatars = find.byType(CoupleCharacterAvatar);
      final messages = find.byType(CharacterSpeechMessage);
      final firstAvatar = tester.getRect(avatars.first);
      expect(firstAvatar.left, 24);
      for (var index = 0; index < 3; index++) {
        expect(tester.getRect(avatars.at(index)).left, firstAvatar.left);
        final message = tester.getRect(messages.at(index));
        final row = find.byType(AiCharacterSpeechRow).at(index);
        final area = tester.getRect(
          find.descendant(
            of: row,
            matching: find.byKey(const Key('character-speech-message-area')),
          ),
        );
        final group = tester.getRect(
          find.descendant(of: row, matching: find.byType(AiGeneratedContent)),
        );
        expect(area.width, closeTo(width - 48 - 108, 0.01));
        expect(group.center.dx, closeTo(area.center.dx, 0.01));
        expect(message.width, lessThanOrEqualTo(area.width));
      }
      final save = tester.getRect(find.widgetWithText(FilledButton, '마음 남기기'));
      final input = tester.getRect(find.byType(CupertinoTextField));
      expect(save.left, input.left);
      expect(save.right, input.right);
      final moment = find.byKey(
        ValueKey('monthly-moment-${DateTime(2026, 9, 5)}'),
      );
      final cards = tester.getRect(
        find.descendant(of: moment, matching: find.byType(MonthlyCardScatter)),
      );
      final question = tester.getRect(find.text('오늘 가장 기억에 남는 순간은?'));
      expect(cards.right, lessThan(question.left));
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.pumpAndSettle();
      expect(_position(tester).pixels, greaterThan(0));
      expect(tester.getRect(find.byType(AppPageHeader)), header);
      expect(tester.takeException(), isNull);
    });
  }

  for (final count in [0, 1, 2, 3, 4, 8, 10, 20, 24]) {
    testWidgets(
      'overview keeps photos above bottom information with $count cards',
      (tester) async {
        await _pump(tester, galleryCount: count);
        final information = tester.getRect(
          find.byKey(const Key('monthly-overview-information')),
        );
        expect(
          information.bottom,
          closeTo(tester.getRect(find.byType(AppBottomBar)).top - 12, 0.01),
        );
        if (count > 0) {
          _expectBalancedPile(tester);
        }
        expect(_position(tester).maxScrollExtent, greaterThan(0));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (count, aspectRatio) in [(3, 1.5), (12, 1.5), (24, 8 / 21)]) {
    testWidgets('balances rotated cards: $count cards at ratio $aspectRatio', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 320,
        galleryCount: count,
        galleryAspectRatio: aspectRatio,
        textScale: 1.6,
      );
      _expectBalancedPile(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview failure leaves retry reachable above the information', (
    tester,
  ) async {
    await _pump(tester, previewFailure: true);
    final retry = find.text('카드 미리보기 다시 불러오기').hitTestable();
    expect(retry.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(retry).bottom,
      lessThan(
        tester
            .getRect(find.byKey(const Key('monthly-overview-information')))
            .top,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'long original answers stay complete and the reflection remains reachable',
    (tester) async {
      await _pump(tester, longAnswers: true);
      final answers = tester.widgetList<QuestionAnswerDisplaySection>(
        find.byType(QuestionAnswerDisplaySection),
      );
      expect(
        answers.where((answer) => answer.body == _answer(true)),
        hasLength(2),
      );
      await tester.ensureVisible(find.byType(CupertinoTextField));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoTextField).hitTestable(), findsOneWidget);
      expect(_position(tester).pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text and keyboard keep input and save clear of the dock', (
    tester,
  ) async {
    await _pump(tester, width: 320, textScale: 1.6, keyboardHeight: 300);
    _expectBalancedPile(tester);
    final date = tester.getRect(find.text('9월 14일').first);
    final annotation = tester.getRect(find.text('둘이 가장 길게 답한 질문'));
    expect(annotation.top, greaterThanOrEqualTo(date.bottom));
    expect(annotation.right, lessThanOrEqualTo(296));
    final title = tester.getRect(find.text('2026년 09월'));
    expect(
      title.left,
      greaterThanOrEqualTo(tester.getRect(find.byTooltip('뒤로가기')).right),
    );
    await tester.ensureVisible(find.byType(CupertinoTextField));
    await tester.enterText(find.byType(CupertinoTextField), '다음 달에도 함께 산책하기');
    final save = find.widgetWithText(FilledButton, '마음 남기기');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(save).width,
      tester.getRect(find.byType(CupertinoTextField)).width,
    );
    expect(
      tester.getRect(save).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(AppBottomBar)).top),
    );
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
      '다음 달에도 함께 산책하기',
    );
    expect(tester.takeException(), isNull);
  });
}

void _expectBalancedPile(WidgetTester tester) {
  final header = tester.getRect(find.byType(AppPageHeader));
  final title = tester.getRect(find.byKey(const Key('monthly-overview-title')));
  final cards = find.descendant(
    of: find.byKey(const Key('monthly-overview')),
    matching: find.byType(StoryCardPreviewSurface),
  );
  Rect? paintedBounds;
  for (final element in cards.evaluate()) {
    final box = element.findRenderObject()! as RenderBox;
    final transform = box.getTransformTo(null);
    var localBounds = Offset.zero & box.size;
    for (final shadow in StoryCardPreviewSurface.shadows) {
      localBounds = localBounds.expandToInclude(
        (Offset.zero & box.size)
            .shift(shadow.offset)
            .inflate(shadow.spreadRadius + shadow.blurSigma * 3),
      );
    }
    final bounds = MatrixUtils.transformRect(transform, localBounds);
    paintedBounds = paintedBounds?.expandToInclude(bounds) ?? bounds;
  }
  final bounds = paintedBounds!;
  final above = bounds.top - header.bottom;
  final below = title.top - bounds.bottom;
  expect(above, greaterThanOrEqualTo(15.99));
  expect(below, closeTo(above, 0.01));
  expect(bounds.left, greaterThanOrEqualTo(23.99));
  expect(
    bounds.right,
    lessThanOrEqualTo(tester.getSize(find.byType(AppShell)).width - 23.99),
  );
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<void> _pump(
  WidgetTester tester, {
  double width = 390,
  bool longAnswers = false,
  double textScale = 1,
  double keyboardHeight = 0,
  int galleryCount = 24,
  double galleryAspectRatio = 0.8,
  bool previewFailure = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        monthlyRetrospectiveControllerProvider.overrideWithBuild(
          (ref, notifier) async =>
              _fixture(longAnswers, galleryCount, galleryAspectRatio),
        ),
        monthlyRetrospectiveRepositoryProvider.overrideWithValue(
          _Repository(fail: previewFailure),
        ),
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
          location: '/monthly',
          child: MonthlyRetrospectiveScreen(onBack: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _answer(bool long) => long
    ? List.filled(80, '같이 커피 마시면서 하루 이야기를 나눴어.').join('\n')
    : '같이 커피 마시며 하루 이야기를 나눈 시간.';

Map<String, Object?> _card(int i, [double aspectRatio = 0.8]) => {
  'id': 'c$i',
  'date': '2026-09-${(i + 1).toString().padLeft(2, '0')}',
  'author_user_id': i.isEven ? 'a' : 'b',
  'preview_path': 'preview-$i',
  'aspect_ratio': aspectRatio,
  'card_type': 'polaroid',
  'layout_version': 2,
};

MonthlyRetrospective _fixture(
  bool long,
  int galleryCount,
  double aspectRatio,
) => MonthlyRetrospective.fromJson({
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
  'gallery': [for (var i = 0; i < galleryCount; i++) _card(i, aspectRatio)],
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
  _Repository({this.fail = false});
  final bool fail;
  @override
  Future<Map<String, String>> previewUrls(
    Iterable<RetrospectiveCard> cards,
  ) async {
    if (fail) throw StateError('preview unavailable');
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
