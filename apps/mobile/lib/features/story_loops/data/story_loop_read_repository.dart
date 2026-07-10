import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/date/app_date_policy.dart';
import '../../couple/data/couple.dart';
import '../../questions/data/daily_question.dart';
import '../../questions/data/daily_question_answer_state.dart';
import 'story_loop_card_detail.dart';
import 'story_loop_card_preview.dart';
import 'story_loop_detail.dart';
import 'story_loop_month_summary_day.dart';
import 'story_loop_question_detail.dart';
import 'story_loop_question_summary.dart';
import 'story_loop_read_failure.dart';
import 'story_loop_status.dart';
import 'today_story_loop_summary.dart';

final storyLoopReadRepositoryProvider = Provider<StoryLoopReadRepository>((
  ref,
) {
  return const SupabaseStoryLoopReadRepository();
});

abstract interface class StoryLoopReadRepository {
  Future<TodayStoryLoopSummary?> fetchTodaySummary();

  Future<StoryLoopDetail?> fetchDetail(DateTime date);

  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(DateTime month);
}

class SupabaseStoryLoopReadRepository implements StoryLoopReadRepository {
  const SupabaseStoryLoopReadRepository();

  static const _previewSignedUrlExpiresInSeconds = 60 * 60;
  static const _bucketId = 'story-cards';

  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() async {
    _ensureSupabaseConfigured();

    try {
      final data = await Supabase.instance.client
          .rpc('get_today_story_loop_summary')
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asOptionalRow(data);

      return row == null ? null : await _parseTodaySummary(row);
    } on TimeoutException {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    _ensureSupabaseConfigured();

    try {
      final data = await Supabase.instance.client
          .rpc(
            'get_story_loop_detail',
            params: {'target_date': _formatDate(date)},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asOptionalRow(data);

      return row == null ? null : await _parseDetail(row);
    } on TimeoutException {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(
    DateTime month,
  ) async {
    _ensureSupabaseConfigured();

    try {
      final data = await Supabase.instance.client
          .rpc(
            'get_story_loop_month_summary',
            params: {'target_month': _formatDate(month)},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      final rows = _asRows(data);

      final summaries = rows.map(_parseMonthSummaryDay).toList(growable: false);
      return _withMonthPreviewUrls(summaries);
    } on TimeoutException {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  void _ensureSupabaseConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const StoryLoopReadRepositoryException(
        StoryLoopReadFailureReason.configMissing,
      );
    }
  }

  Future<TodayStoryLoopSummary> _parseTodaySummary(
    Map<String, dynamic> row,
  ) async {
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
      cards: await _withPreviewUrls(_parsePreviewCards(row)),
      question: _parseQuestionSummary(row),
    );
  }

  Future<StoryLoopDetail> _parseDetail(Map<String, dynamic> row) async {
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
      cards: await _withDetailPreviewUrls(_parseDetailCards(row)),
      question: _parseQuestionDetail(row),
    );
  }

  StoryLoopMonthSummaryDay _parseMonthSummaryDay(Map<String, dynamic> row) {
    return StoryLoopMonthSummaryDay(
      coupleDate: _parseDate(row['couple_date']),
      loopStatus: StoryLoopStatus.fromJson(row['loop_status'] as String),
      cardCount: _toInt(row['card_count']),
      cards: _parsePreviewCards(row),
    );
  }

  StoryLoopQuestionSummary? _parseQuestionSummary(Map<String, dynamic> row) {
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

  StoryLoopQuestionDetail? _parseQuestionDetail(Map<String, dynamic> row) {
    if (row['daily_question_id'] == null) {
      return null;
    }

    return StoryLoopQuestionDetail(
      question: DailyQuestion.fromJson(_toDailyQuestionJson(row)),
      answerState: DailyQuestionAnswerState.fromJson(_toAnswerStateJson(row)),
    );
  }

  List<StoryLoopCardPreview> _parsePreviewCards(Map<String, dynamic> row) {
    final cards = <StoryLoopCardPreview>[];

    final firstCardId = row['first_card_id'] as String?;
    if (firstCardId != null) {
      cards.add(
        StoryLoopCardPreview(
          id: firstCardId,
          authorUserId: row['first_card_author_user_id'] as String,
          previewPath: row['first_card_preview_path'] as String,
          submittedAt: _parseDateTime(row['first_card_submitted_at']),
        ),
      );
    }

    final secondCardId = row['second_card_id'] as String?;
    if (secondCardId != null) {
      cards.add(
        StoryLoopCardPreview(
          id: secondCardId,
          authorUserId: row['second_card_author_user_id'] as String,
          previewPath: row['second_card_preview_path'] as String,
          submittedAt: _parseDateTime(row['second_card_submitted_at']),
        ),
      );
    }

    return cards;
  }

  List<StoryLoopCardDetail> _parseDetailCards(Map<String, dynamic> row) {
    final cards = <StoryLoopCardDetail>[];

    final firstCardId = row['first_card_id'] as String?;
    if (firstCardId != null) {
      cards.add(
        StoryLoopCardDetail(
          id: firstCardId,
          authorUserId: row['first_card_author_user_id'] as String,
          previewPath: row['first_card_preview_path'] as String,
          sceneDataPath: row['first_card_scene_data_path'] as String,
          hasPhoto: row['first_card_has_photo'] as bool? ?? false,
          hasDrawing: row['first_card_has_drawing'] as bool? ?? false,
          hasText: row['first_card_has_text'] as bool? ?? false,
          submittedAt: _parseDateTime(row['first_card_submitted_at']),
          revision: _toInt(row['first_card_revision']),
        ),
      );
    }

    final secondCardId = row['second_card_id'] as String?;
    if (secondCardId != null) {
      cards.add(
        StoryLoopCardDetail(
          id: secondCardId,
          authorUserId: row['second_card_author_user_id'] as String,
          previewPath: row['second_card_preview_path'] as String,
          sceneDataPath: row['second_card_scene_data_path'] as String,
          hasPhoto: row['second_card_has_photo'] as bool? ?? false,
          hasDrawing: row['second_card_has_drawing'] as bool? ?? false,
          hasText: row['second_card_has_text'] as bool? ?? false,
          submittedAt: _parseDateTime(row['second_card_submitted_at']),
          revision: _toInt(row['second_card_revision']),
        ),
      );
    }

    return cards;
  }

  Future<List<StoryLoopCardPreview>> _withPreviewUrls(
    List<StoryLoopCardPreview> cards,
  ) async {
    final urlsByPath = await _createPreviewUrlsByPath(
      cards.map((card) => card.previewPath),
    );

    return _applyPreviewUrls(cards, urlsByPath);
  }

  Future<List<StoryLoopMonthSummaryDay>> _withMonthPreviewUrls(
    List<StoryLoopMonthSummaryDay> summaries,
  ) async {
    final urlsByPath = await _createPreviewUrlsByPath(
      summaries.expand(
        (summary) => summary.cards.map((card) => card.previewPath),
      ),
    );

    return summaries
        .map(
          (summary) => summary.copyWith(
            cards: _applyPreviewUrls(summary.cards, urlsByPath),
          ),
        )
        .toList(growable: false);
  }

  List<StoryLoopCardPreview> _applyPreviewUrls(
    List<StoryLoopCardPreview> cards,
    Map<String, String> urlsByPath,
  ) {
    return cards
        .map((card) => card.copyWith(previewUrl: urlsByPath[card.previewPath]))
        .toList(growable: false);
  }

  Future<List<StoryLoopCardDetail>> _withDetailPreviewUrls(
    List<StoryLoopCardDetail> cards,
  ) async {
    final urlsByPath = await _createPreviewUrlsByPath(
      cards.map((card) => card.previewPath),
    );

    return cards
        .map((card) => card.copyWith(previewUrl: urlsByPath[card.previewPath]))
        .toList(growable: false);
  }

  Future<Map<String, String>> _createPreviewUrlsByPath(
    Iterable<String> paths,
  ) async {
    final uniquePaths = paths.toSet().toList(growable: false);
    if (uniquePaths.isEmpty) {
      return const {};
    }

    try {
      final signedUrls = await _bucket
          .createSignedUrls(uniquePaths, _previewSignedUrlExpiresInSeconds)
          .timeout(AppConfig.supabaseRpcTimeout);

      return {
        for (final signedUrl in signedUrls)
          if (signedUrl.path.isNotEmpty) signedUrl.path: signedUrl.signedUrl,
      };
    } on TimeoutException {
      return const {};
    } on StorageException {
      return const {};
    }
  }

  StorageFileApi get _bucket =>
      Supabase.instance.client.storage.from(_bucketId);

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

  Map<String, dynamic>? _asOptionalRow(Object? data) {
    if (data == null) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List) {
      if (data.isEmpty) {
        return null;
      }

      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw const StoryLoopReadRepositoryException(
      StoryLoopReadFailureReason.unknown,
    );
  }

  List<Map<String, dynamic>> _asRows(Object? data) {
    if (data == null) {
      return const [];
    }

    if (data is List<Map<String, dynamic>>) {
      return data;
    }

    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    final row = _asOptionalRow(data);
    if (row == null) {
      return const [];
    }

    return [row];
  }

  StoryLoopReadRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return StoryLoopReadRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  StoryLoopReadFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => StoryLoopReadFailureReason.authRequired,
      'relationship_date_required' =>
        StoryLoopReadFailureReason.relationshipDateRequired,
      _ => StoryLoopReadFailureReason.unknown,
    };
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
