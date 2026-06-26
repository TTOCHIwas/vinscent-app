import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';

const pendingAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.pending,
  partnerAnswerExists: false,
  answerCount: 0,
);

const partnerAnsweredOnlyState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.answeredByOne,
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 1,
);

const completedAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.completed,
  myAnswerId: 'answer-id',
  myAnswerText: 'hello',
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 2,
);

DailyQuestionAnswerState myAnswerOnlyState({
  String myAnswerId = 'answer-id',
  String myAnswerText = 'hello',
}) {
  return DailyQuestionAnswerState(
    dailyQuestionId: 'daily-question-id',
    status: DailyQuestionStatus.answeredByOne,
    myAnswerId: myAnswerId,
    myAnswerText: myAnswerText,
    partnerAnswerExists: false,
    answerCount: 1,
  );
}

class FakeDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  FakeDailyQuestionAnswerRepository(
    this.currentState, {
    DailyQuestionAnswerState? submittedState,
    this.submitError,
  }) : submittedState = submittedState ?? currentState;

  DailyQuestionAnswerState currentState;
  final DailyQuestionAnswerState submittedState;
  final Object? submitError;
  final submittedAnswers = <String>[];
  var fetchCallCount = 0;
  var submitCallCount = 0;

  @override
  Future<DailyQuestionAnswerState> fetchTodayAnswerState() async {
    fetchCallCount += 1;
    return currentState;
  }

  @override
  Future<DailyQuestionAnswerState> submitTodayAnswer(String answerText) async {
    submitCallCount += 1;
    submittedAnswers.add(answerText);
    final submitError = this.submitError;
    if (submitError != null) {
      throw submitError;
    }

    currentState = submittedState;
    return submittedState;
  }
}
