import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_question_feedback_snapshot.dart';

void main() {
  test('parses processing and failed feedback states', () {
    expect(
      AiQuestionFeedbackSnapshot.fromJson({
        'status': 'processing',
        'feedback': null,
      }),
      isA<AiQuestionFeedbackSnapshotProcessing>(),
    );
    expect(
      AiQuestionFeedbackSnapshot.fromJson({
        'status': 'failed',
        'feedback': null,
      }),
      isA<AiQuestionFeedbackSnapshotFailed>(),
    );
  });

  test('parses published feedback as a typed result', () {
    final snapshot = AiQuestionFeedbackSnapshot.fromJson({
      'status': 'published',
      'feedback': {
        'daily_question_id': 'daily-question-id',
        'feedback_text': '오늘 밤 영화 한 편이면 소파가 꽤 바빠지겠네!',
        'published_at': '2026-08-17T10:15:12Z',
      },
    });

    expect(snapshot, isA<AiQuestionFeedbackSnapshotPublished>());
    final published = snapshot as AiQuestionFeedbackSnapshotPublished;
    expect(published.feedback.dailyQuestionId, 'daily-question-id');
    expect(published.feedback.feedbackText, '오늘 밤 영화 한 편이면 소파가 꽤 바빠지겠네!');
  });

  test('rejects a published state without feedback data', () {
    expect(
      () => AiQuestionFeedbackSnapshot.fromJson({
        'status': 'published',
        'feedback': null,
      }),
      throwsFormatException,
    );
  });
}
