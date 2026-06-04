import 'daily_question.dart';
import 'daily_question_answer_state.dart';

enum QuestionDetailUnavailableReason {
  invalidDate,
  unavailable,
  beforeRelationshipStartDate,
  futureDate,
  noQuestion,
}

sealed class QuestionDetailState {
  const QuestionDetailState();
}

class LoadedQuestionDetailState extends QuestionDetailState {
  const LoadedQuestionDetailState({
    required this.question,
    required this.answerState,
    required this.canEdit,
  });

  final DailyQuestion question;
  final DailyQuestionAnswerState? answerState;
  final bool canEdit;
}

class UnavailableQuestionDetailState extends QuestionDetailState {
  const UnavailableQuestionDetailState({
    required this.reason,
    required this.targetDate,
  });

  final QuestionDetailUnavailableReason reason;
  final DateTime targetDate;
}
