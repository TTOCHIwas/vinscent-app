import '../../questions/data/daily_question.dart';
import '../../questions/data/daily_question_answer_state.dart';

class DailyQuestionHistoryEntry {
  const DailyQuestionHistoryEntry({
    required this.question,
    required this.answerState,
  });

  factory DailyQuestionHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DailyQuestionHistoryEntry(
      question: DailyQuestion.fromJson(json),
      answerState: DailyQuestionAnswerState.fromJson(json),
    );
  }

  final DailyQuestion question;
  final DailyQuestionAnswerState answerState;
}
