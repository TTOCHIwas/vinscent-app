import '../../../core/questions/daily_question.dart';

class StoryLoopQuestionSummary {
  const StoryLoopQuestionSummary({
    required this.question,
    required this.myAnswerExists,
    required this.partnerAnswerExists,
    required this.answerCount,
  });

  final DailyQuestion question;
  final bool myAnswerExists;
  final bool partnerAnswerExists;
  final int answerCount;
}
