import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';

void main() {
  test('parses daily question response', () {
    final question = DailyQuestion.fromJson({
      'daily_question_id': 'daily-question-id',
      'couple_id': 'couple-id',
      'question_id': 'question-id',
      'question_text': '오늘의 질문',
      'question_source': 'curated',
      'question_category': 'daily',
      'question_mood': 'warm',
      'assigned_date': '2026-05-31',
      'status': 'pending',
    });

    expect(question.dailyQuestionId, 'daily-question-id');
    expect(question.coupleId, 'couple-id');
    expect(question.questionId, 'question-id');
    expect(question.questionText, '오늘의 질문');
    expect(question.questionSource, QuestionSource.curated);
    expect(question.questionCategory, 'daily');
    expect(question.questionMood, 'warm');
    expect(question.assignedDate, DateTime(2026, 5, 31));
    expect(question.status, DailyQuestionStatus.pending);
  });

  test('normalizes assigned date to date only', () {
    final question = DailyQuestion.fromJson({
      'daily_question_id': 'daily-question-id',
      'couple_id': 'couple-id',
      'question_id': 'question-id',
      'question_text': '오늘의 질문',
      'question_source': 'ai',
      'question_category': 'daily',
      'question_mood': null,
      'assigned_date': '2026-05-31T12:30:00Z',
      'status': 'completed',
    });

    expect(question.questionSource, QuestionSource.ai);
    expect(question.questionMood, isNull);
    expect(question.assignedDate, DateTime(2026, 5, 31));
    expect(question.status, DailyQuestionStatus.completed);
  });

  test('throws when source is unknown', () {
    expect(
      () => DailyQuestion.fromJson({
        'daily_question_id': 'daily-question-id',
        'couple_id': 'couple-id',
        'question_id': 'question-id',
        'question_text': '오늘의 질문',
        'question_source': 'manual',
        'question_category': 'daily',
        'question_mood': null,
        'assigned_date': '2026-05-31',
        'status': 'pending',
      }),
      throwsFormatException,
    );
  });

  test('throws when status is unknown', () {
    expect(
      () => DailyQuestion.fromJson({
        'daily_question_id': 'daily-question-id',
        'couple_id': 'couple-id',
        'question_id': 'question-id',
        'question_text': '오늘의 질문',
        'question_source': 'curated',
        'question_category': 'daily',
        'question_mood': null,
        'assigned_date': '2026-05-31',
        'status': 'skipped',
      }),
      throwsFormatException,
    );
  });
}
