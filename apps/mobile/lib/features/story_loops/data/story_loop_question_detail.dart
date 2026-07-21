import '../../../core/questions/daily_question.dart';
import '../../../core/questions/daily_question_answer_state.dart';

class StoryLoopQuestionDetail {
  const StoryLoopQuestionDetail({
    required this.question,
    required this.answerState,
  });

  final DailyQuestion question;
  final DailyQuestionAnswerState answerState;
}
