import '../../../core/date/app_date_policy.dart';
import '../../../core/questions/daily_question.dart';
import '../../../core/questions/daily_question_answer_state.dart';
import '../../couple/data/couple.dart';
import 'story_loop_card_detail.dart';
import 'story_loop_card_preview.dart';
import 'story_loop_detail.dart';
import 'story_loop_month_summary_day.dart';
import 'story_loop_question_detail.dart';
import 'story_loop_question_summary.dart';
import 'story_loop_status.dart';
import 'today_story_loop_summary.dart';

class StoryLoopReadMapper {
  const StoryLoopReadMapper();

  TodayStoryLoopSummary mapTodaySummary(
    Map<String, dynamic> row, {
    Map<String, String> previewUrlsByPath = const {},
  }) {
    return TodayStoryLoopSummary(
      coupleId: row['couple_id'] as String,
      coupleDate: _parseDate(row['couple_date']),
      accessMode: CoupleAccessMode.fromJson(row['access_mode'] as String),
      loopId: row['loop_id'] as String?,
      loopStatus: _parseOptionalLoopStatus(row['loop_status']),
      storyEditLocked: row['story_edit_locked'] as bool? ?? false,
      canEditStory: row['can_edit_story'] as bool? ?? false,
      canAnswerQuestion: row['can_answer_question'] as bool? ?? false,
      cardCount: _toInt(row['card_count']),
      cards: _mapPreviewCards(row, previewUrlsByPath),
      question: _mapQuestionSummary(row),
    );
  }

  StoryLoopDetail mapDetail(
    Map<String, dynamic> row, {
    Map<String, String> previewUrlsByPath = const {},
  }) {
    return StoryLoopDetail(
      coupleId: row['couple_id'] as String,
      coupleDate: _parseDate(row['couple_date']),
      accessMode: CoupleAccessMode.fromJson(row['access_mode'] as String),
      loopId: row['loop_id'] as String?,
      loopStatus: _parseOptionalLoopStatus(row['loop_status']),
      storyEditLocked: row['story_edit_locked'] as bool? ?? false,
      canEditStory: row['can_edit_story'] as bool? ?? false,
      canAnswerQuestion: row['can_answer_question'] as bool? ?? false,
      cardCount: _toInt(row['card_count']),
      cards: _mapDetailCards(row, previewUrlsByPath),
      question: _mapQuestionDetail(row),
    );
  }

  StoryLoopMonthSummaryDay mapMonthSummaryDay(
    Map<String, dynamic> row, {
    Map<String, String> previewUrlsByPath = const {},
  }) {
    return StoryLoopMonthSummaryDay(
      coupleDate: _parseDate(row['couple_date']),
      loopStatus: StoryLoopStatus.fromJson(row['loop_status'] as String),
      cardCount: _toInt(row['card_count']),
      cards: _mapPreviewCards(row, previewUrlsByPath),
    );
  }

  StoryLoopQuestionSummary? _mapQuestionSummary(Map<String, dynamic> row) {
    if (row['daily_question_id'] == null) {
      return null;
    }

    return StoryLoopQuestionSummary(
      question: DailyQuestion.fromJson(_toDailyQuestionJson(row)),
      myAnswerExists: row['my_answer_exists'] as bool? ?? false,
      partnerAnswerExists: row['partner_answer_exists'] as bool? ?? false,
      answerCount: _toInt(row['answer_count']),
    );
  }

  StoryLoopQuestionDetail? _mapQuestionDetail(Map<String, dynamic> row) {
    if (row['daily_question_id'] == null) {
      return null;
    }

    return StoryLoopQuestionDetail(
      question: DailyQuestion.fromJson(_toDailyQuestionJson(row)),
      answerState: DailyQuestionAnswerState.fromJson(_toAnswerStateJson(row)),
    );
  }

  List<StoryLoopCardPreview> _mapPreviewCards(
    Map<String, dynamic> row,
    Map<String, String> previewUrlsByPath,
  ) {
    final cards = <StoryLoopCardPreview>[];

    final firstCardId = row['first_card_id'] as String?;
    if (firstCardId != null) {
      final previewPath = row['first_card_preview_path'] as String;
      cards.add(
        StoryLoopCardPreview(
          id: firstCardId,
          authorUserId: row['first_card_author_user_id'] as String,
          previewPath: previewPath,
          submittedAt: _parseDateTime(row['first_card_submitted_at']),
          previewUrl: previewUrlsByPath[previewPath],
        ),
      );
    }

    final secondCardId = row['second_card_id'] as String?;
    if (secondCardId != null) {
      final previewPath = row['second_card_preview_path'] as String;
      cards.add(
        StoryLoopCardPreview(
          id: secondCardId,
          authorUserId: row['second_card_author_user_id'] as String,
          previewPath: previewPath,
          submittedAt: _parseDateTime(row['second_card_submitted_at']),
          previewUrl: previewUrlsByPath[previewPath],
        ),
      );
    }

    return cards;
  }

  List<StoryLoopCardDetail> _mapDetailCards(
    Map<String, dynamic> row,
    Map<String, String> previewUrlsByPath,
  ) {
    final cards = <StoryLoopCardDetail>[];

    final firstCardId = row['first_card_id'] as String?;
    if (firstCardId != null) {
      cards.add(
        _mapDetailCard(
          row,
          prefix: 'first_card',
          cardId: firstCardId,
          previewUrlsByPath: previewUrlsByPath,
        ),
      );
    }

    final secondCardId = row['second_card_id'] as String?;
    if (secondCardId != null) {
      cards.add(
        _mapDetailCard(
          row,
          prefix: 'second_card',
          cardId: secondCardId,
          previewUrlsByPath: previewUrlsByPath,
        ),
      );
    }

    return cards;
  }

  StoryLoopCardDetail _mapDetailCard(
    Map<String, dynamic> row, {
    required String prefix,
    required String cardId,
    required Map<String, String> previewUrlsByPath,
  }) {
    final previewPath = row['${prefix}_preview_path'] as String;
    return StoryLoopCardDetail(
      id: cardId,
      authorUserId: row['${prefix}_author_user_id'] as String,
      previewPath: previewPath,
      sceneDataPath: row['${prefix}_scene_data_path'] as String,
      hasPhoto: row['${prefix}_has_photo'] as bool? ?? false,
      hasDrawing: row['${prefix}_has_drawing'] as bool? ?? false,
      hasText: row['${prefix}_has_text'] as bool? ?? false,
      submittedAt: _parseDateTime(row['${prefix}_submitted_at']),
      revision: _toInt(row['${prefix}_revision']),
      previewUrl: previewUrlsByPath[previewPath],
    );
  }

  Map<String, dynamic> _toDailyQuestionJson(Map<String, dynamic> row) {
    return {
      'daily_question_id': row['daily_question_id'],
      'couple_id': row['couple_id'],
      'question_id': row['question_id'],
      'question_text': row['question_text'],
      'question_source': row['question_source'],
      'question_category': row['question_category'],
      'question_mood': row['question_mood'],
      'assigned_date': row['couple_date'],
      'status': row['question_status'],
    };
  }

  Map<String, dynamic> _toAnswerStateJson(Map<String, dynamic> row) {
    return {
      'daily_question_id': row['daily_question_id'],
      'status': row['question_status'],
      'my_answer_id': row['my_answer_id'],
      'my_answer_text': row['my_answer_text'],
      'my_answer_answered_at': row['my_answer_answered_at'],
      'my_answer_updated_at': row['my_answer_updated_at'],
      'partner_answer_exists': row['partner_answer_exists'],
      'partner_answer_id': row['partner_answer_id'],
      'partner_answer_text': row['partner_answer_text'],
      'partner_answer_answered_at': row['partner_answer_answered_at'],
      'partner_answer_updated_at': row['partner_answer_updated_at'],
      'answer_count': row['answer_count'],
    };
  }

  StoryLoopStatus? _parseOptionalLoopStatus(Object? value) {
    if (value == null) {
      return null;
    }

    return StoryLoopStatus.fromJson(value as String);
  }

  DateTime _parseDate(Object? value) {
    return calendarDateOnly(DateTime.parse(value as String));
  }

  DateTime _parseDateTime(Object? value) {
    return DateTime.parse(value as String);
  }

  int _toInt(Object? value) {
    return (value as num?)?.toInt() ?? 0;
  }
}
