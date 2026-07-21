import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/questions/daily_question.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_mapper.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';

void main() {
  const mapper = StoryLoopReadMapper();

  test('maps the today summary RPC row including cards and question', () {
    final summary = mapper.mapTodaySummary(
      _summaryRow(),
      previewUrlsByPath: const {
        'cards/first.png': 'https://example.com/first',
        'cards/second.png': 'https://example.com/second',
      },
    );

    expect(summary.coupleId, 'couple-1');
    expect(summary.coupleDate, DateTime(2026, 7, 21));
    expect(summary.accessMode, CoupleAccessMode.active);
    expect(summary.loopStatus, StoryLoopStatus.questionGenerated);
    expect(summary.storyEditLocked, isTrue);
    expect(summary.canEditStory, isFalse);
    expect(summary.canAnswerQuestion, isTrue);
    expect(summary.cardCount, 2);
    expect(summary.cards, hasLength(2));
    expect(summary.cards.first.id, 'card-1');
    expect(summary.cards.first.previewUrl, 'https://example.com/first');
    expect(summary.cards.last.id, 'card-2');
    expect(summary.cards.last.previewUrl, 'https://example.com/second');
    expect(summary.question?.question.questionSource, QuestionSource.curated);
    expect(
      summary.question?.question.status,
      DailyQuestionStatus.answeredByOne,
    );
    expect(summary.question?.myAnswerExists, isTrue);
    expect(summary.question?.partnerAnswerExists, isFalse);
    expect(summary.question?.answerCount, 1);
  });

  test('maps the detail RPC row including answer state', () {
    final detail = mapper.mapDetail(
      {
        ..._summaryRow(),
        'loop_status': 'completed',
        'question_status': 'completed',
        'first_card_scene_data_path': 'cards/first.json',
        'first_card_has_photo': true,
        'first_card_has_drawing': true,
        'first_card_has_text': false,
        'first_card_revision': 3.0,
        'second_card_scene_data_path': 'cards/second.json',
        'second_card_has_photo': false,
        'second_card_has_drawing': true,
        'second_card_has_text': true,
        'second_card_revision': 4,
        'my_answer_id': 'answer-1',
        'my_answer_text': '내 답변',
        'my_answer_answered_at': '2026-07-21T09:00:00Z',
        'my_answer_updated_at': '2026-07-21T09:01:00Z',
        'partner_answer_exists': true,
        'partner_answer_id': 'answer-2',
        'partner_answer_text': '상대 답변',
        'partner_answer_answered_at': '2026-07-21T10:00:00Z',
        'partner_answer_updated_at': '2026-07-21T10:01:00Z',
        'answer_count': 2,
      },
      previewUrlsByPath: const {'cards/first.png': 'https://example.com/first'},
    );

    expect(detail.loopStatus, StoryLoopStatus.completed);
    expect(detail.cards, hasLength(2));
    expect(detail.cards.first.sceneDataPath, 'cards/first.json');
    expect(detail.cards.first.revision, 3);
    expect(detail.cards.first.previewUrl, 'https://example.com/first');
    expect(detail.cards.last.hasText, isTrue);
    expect(detail.question?.answerState.hasBothAnswers, isTrue);
    expect(detail.question?.answerState.myAnswerText, '내 답변');
    expect(detail.question?.answerState.partnerAnswerText, '상대 답변');
    expect(detail.question?.answerState.answerCount, 2);
  });

  test('maps a month row and omits absent cards and questions', () {
    final monthDay = mapper.mapMonthSummaryDay({
      'couple_date': '2026-07-22',
      'loop_status': 'waiting_partner_card',
      'card_count': 1,
      'first_card_id': 'card-3',
      'first_card_author_user_id': 'user-1',
      'first_card_preview_path': 'cards/third.png',
      'first_card_submitted_at': '2026-07-22T08:00:00Z',
      'second_card_id': null,
    });

    expect(monthDay.coupleDate, DateTime(2026, 7, 22));
    expect(monthDay.loopStatus, StoryLoopStatus.waitingPartnerCard);
    expect(monthDay.cardCount, 1);
    expect(monthDay.cards.single.id, 'card-3');

    final summary = mapper.mapTodaySummary({
      'couple_id': 'couple-1',
      'couple_date': '2026-07-22',
      'access_mode': 'active',
      'loop_id': null,
      'loop_status': null,
      'card_count': null,
      'daily_question_id': null,
    });

    expect(summary.storyEditLocked, isFalse);
    expect(summary.canEditStory, isFalse);
    expect(summary.canAnswerQuestion, isFalse);
    expect(summary.cardCount, 0);
    expect(summary.cards, isEmpty);
    expect(summary.question, isNull);
  });
}

Map<String, dynamic> _summaryRow() {
  return {
    'couple_id': 'couple-1',
    'couple_date': '2026-07-21',
    'access_mode': 'active',
    'loop_id': 'loop-1',
    'loop_status': 'question_generated',
    'story_edit_locked': true,
    'can_edit_story': false,
    'can_answer_question': true,
    'card_count': 2.0,
    'first_card_id': 'card-1',
    'first_card_author_user_id': 'user-1',
    'first_card_preview_path': 'cards/first.png',
    'first_card_submitted_at': '2026-07-21T08:00:00Z',
    'second_card_id': 'card-2',
    'second_card_author_user_id': 'user-2',
    'second_card_preview_path': 'cards/second.png',
    'second_card_submitted_at': '2026-07-21T08:30:00Z',
    'daily_question_id': 'daily-question-1',
    'question_id': 'question-1',
    'question_text': '서로 닮았다고 느낀 순간은?',
    'question_source': 'curated',
    'question_category': 'relationship',
    'question_mood': 'warm',
    'question_status': 'answered_by_one',
    'my_answer_exists': true,
    'partner_answer_exists': false,
    'answer_count': 1.0,
  };
}
