import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/story_loops/data/story_loop_card_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_card_preview.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_summary.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary.dart';

class FakeStoryLoopReadRepository implements StoryLoopReadRepository {
  FakeStoryLoopReadRepository({
    this.todaySummary,
    Map<DateTime, StoryLoopDetail?> details = const {},
    Map<DateTime, List<StoryLoopMonthSummaryDay>> monthSummaries = const {},
  }) : _details = {
         for (final entry in details.entries)
           calendarDateOnly(entry.key): entry.value,
       },
       _monthSummaries = {
         for (final entry in monthSummaries.entries)
           DateTime(entry.key.year, entry.key.month): entry.value,
       };

  final TodayStoryLoopSummary? todaySummary;
  final Map<DateTime, StoryLoopDetail?> _details;
  final Map<DateTime, List<StoryLoopMonthSummaryDay>> _monthSummaries;

  var todaySummaryCallCount = 0;
  final requestedDetailDates = <DateTime>[];
  final requestedMonths = <DateTime>[];

  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() async {
    todaySummaryCallCount += 1;
    return todaySummary;
  }

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    final normalizedDate = calendarDateOnly(date);
    requestedDetailDates.add(normalizedDate);
    return _details[normalizedDate];
  }

  @override
  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(DateTime month) async {
    final normalizedMonth = DateTime(month.year, month.month);
    requestedMonths.add(normalizedMonth);
    return _monthSummaries[normalizedMonth] ?? const [];
  }
}

DailyQuestion sampleDailyQuestion({
  DateTime? assignedDate,
  DailyQuestionStatus status = DailyQuestionStatus.pending,
}) {
  return DailyQuestion(
    dailyQuestionId: 'daily-question-id',
    coupleId: 'couple-id',
    questionId: 'question-id',
    questionText: '오늘 질문',
    questionSource: QuestionSource.curated,
    questionCategory: 'daily',
    questionMood: 'warm',
    assignedDate: assignedDate ?? DateTime(2026, 7, 6),
    status: status,
  );
}

DailyQuestionAnswerState sampleAnswerState({
  DailyQuestionStatus status = DailyQuestionStatus.completed,
  bool hasMyAnswer = true,
  bool hasPartnerAnswer = true,
  int answerCount = 2,
}) {
  return DailyQuestionAnswerState(
    dailyQuestionId: 'daily-question-id',
    status: status,
    myAnswerId: hasMyAnswer ? 'my-answer-id' : null,
    myAnswerText: hasMyAnswer ? '내 답변' : null,
    partnerAnswerExists: hasPartnerAnswer,
    partnerAnswerId: hasPartnerAnswer ? 'partner-answer-id' : null,
    partnerAnswerText: hasPartnerAnswer ? '상대 답변' : null,
    answerCount: answerCount,
  );
}

StoryLoopCardPreview samplePreviewCard({
  String id = 'card-1',
  String authorUserId = 'user-a',
  String previewPath = 'previews/card-1.png',
  DateTime? submittedAt,
}) {
  return StoryLoopCardPreview(
    id: id,
    authorUserId: authorUserId,
    previewPath: previewPath,
    submittedAt: submittedAt ?? DateTime.parse('2026-07-06T09:00:00Z'),
  );
}

StoryLoopCardDetail sampleDetailCard({
  String id = 'card-1',
  String authorUserId = 'user-a',
  String previewPath = 'previews/card-1.png',
  String sceneDataPath = 'scenes/card-1.json',
  bool hasPhoto = true,
  bool hasDrawing = false,
  bool hasText = true,
  DateTime? submittedAt,
  int revision = 1,
}) {
  return StoryLoopCardDetail(
    id: id,
    authorUserId: authorUserId,
    previewPath: previewPath,
    sceneDataPath: sceneDataPath,
    hasPhoto: hasPhoto,
    hasDrawing: hasDrawing,
    hasText: hasText,
    submittedAt: submittedAt ?? DateTime.parse('2026-07-06T09:00:00Z'),
    revision: revision,
  );
}

TodayStoryLoopSummary sampleTodaySummary({
  String coupleId = 'couple-id',
  DateTime? coupleDate,
  CoupleAccessMode accessMode = CoupleAccessMode.active,
  String? loopId = 'loop-id',
  StoryLoopStatus? loopStatus = StoryLoopStatus.questionGenerated,
  bool storyEditLocked = true,
  bool canEditStory = false,
  bool canAnswerQuestion = true,
  int cardCount = 2,
  List<StoryLoopCardPreview>? cards,
  StoryLoopQuestionSummary? question,
}) {
  return TodayStoryLoopSummary(
    coupleId: coupleId,
    coupleDate: coupleDate ?? DateTime(2026, 7, 6),
    accessMode: accessMode,
    loopId: loopId,
    loopStatus: loopStatus,
    storyEditLocked: storyEditLocked,
    canEditStory: canEditStory,
    canAnswerQuestion: canAnswerQuestion,
    cardCount: cardCount,
    cards:
        cards ??
        [
          samplePreviewCard(),
          samplePreviewCard(
            id: 'card-2',
            authorUserId: 'user-b',
            previewPath: 'previews/card-2.png',
            submittedAt: DateTime.parse('2026-07-06T09:10:00Z'),
          ),
        ],
    question:
        question ??
        StoryLoopQuestionSummary(
          question: sampleDailyQuestion(),
          myAnswerExists: false,
          partnerAnswerExists: false,
          answerCount: 0,
        ),
  );
}

StoryLoopDetail sampleStoryLoopDetail({
  String coupleId = 'couple-id',
  DateTime? coupleDate,
  CoupleAccessMode accessMode = CoupleAccessMode.active,
  String? loopId = 'loop-id',
  StoryLoopStatus? loopStatus = StoryLoopStatus.completed,
  bool storyEditLocked = true,
  bool canEditStory = false,
  bool canAnswerQuestion = true,
  int cardCount = 2,
  List<StoryLoopCardDetail>? cards,
  StoryLoopQuestionDetail? question,
}) {
  return StoryLoopDetail(
    coupleId: coupleId,
    coupleDate: coupleDate ?? DateTime(2026, 7, 6),
    accessMode: accessMode,
    loopId: loopId,
    loopStatus: loopStatus,
    storyEditLocked: storyEditLocked,
    canEditStory: canEditStory,
    canAnswerQuestion: canAnswerQuestion,
    cardCount: cardCount,
    cards:
        cards ??
        [
          sampleDetailCard(),
          sampleDetailCard(
            id: 'card-2',
            authorUserId: 'user-b',
            previewPath: 'previews/card-2.png',
            sceneDataPath: 'scenes/card-2.json',
            submittedAt: DateTime.parse('2026-07-06T09:10:00Z'),
          ),
        ],
    question:
        question ??
        StoryLoopQuestionDetail(
          question: sampleDailyQuestion(status: DailyQuestionStatus.completed),
          answerState: sampleAnswerState(),
        ),
  );
}

StoryLoopDetail sampleEmptyStoryLoopDetail({
  String coupleId = 'couple-id',
  DateTime? coupleDate,
  CoupleAccessMode accessMode = CoupleAccessMode.active,
  bool canEditStory = true,
}) {
  return StoryLoopDetail(
    coupleId: coupleId,
    coupleDate: coupleDate ?? DateTime(2026, 7, 6),
    accessMode: accessMode,
    loopId: null,
    loopStatus: null,
    storyEditLocked: false,
    canEditStory: canEditStory,
    canAnswerQuestion: false,
    cardCount: 0,
    cards: const [],
    question: null,
  );
}

StoryLoopMonthSummaryDay sampleMonthSummaryDay({
  DateTime? coupleDate,
  StoryLoopStatus loopStatus = StoryLoopStatus.waitingPartnerCard,
  int cardCount = 1,
  List<StoryLoopCardPreview>? cards,
}) {
  return StoryLoopMonthSummaryDay(
    coupleDate: coupleDate ?? DateTime(2026, 7, 6),
    loopStatus: loopStatus,
    cardCount: cardCount,
    cards: cards ?? [samplePreviewCard()],
  );
}
