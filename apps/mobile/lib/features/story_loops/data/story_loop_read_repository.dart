import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'story_loop_detail.dart';
import 'story_loop_month_summary_day.dart';
import 'story_loop_read_failure.dart';
import 'story_loop_read_mapper.dart';
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
  const SupabaseStoryLoopReadRepository({
    StoryLoopReadMapper mapper = const StoryLoopReadMapper(),
  }) : _mapper = mapper;

  static const _previewSignedUrlExpiresInSeconds = 60 * 60;
  static const _bucketId = 'story-cards';

  final StoryLoopReadMapper _mapper;

  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() async {
    _ensureSupabaseConfigured();

    try {
      final data = await Supabase.instance.client
          .rpc('get_today_story_loop_summary')
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asOptionalRow(data);
      if (row == null) {
        return null;
      }

      final summary = _mapper.mapTodaySummary(row);
      final previewUrlsByPath = await _createPreviewUrlsByPath(
        summary.cards.map((card) => card.previewPath),
      );
      return _mapper.mapTodaySummary(row, previewUrlsByPath: previewUrlsByPath);
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
      if (row == null) {
        return null;
      }

      final detail = _mapper.mapDetail(row);
      final previewUrlsByPath = await _createPreviewUrlsByPath(
        detail.cards.map((card) => card.previewPath),
      );
      return _mapper.mapDetail(row, previewUrlsByPath: previewUrlsByPath);
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

      final summaries = rows
          .map(_mapper.mapMonthSummaryDay)
          .toList(growable: false);
      final previewUrlsByPath = await _createPreviewUrlsByPath(
        summaries.expand(
          (summary) => summary.cards.map((card) => card.previewPath),
        ),
      );
      return rows
          .map(
            (row) => _mapper.mapMonthSummaryDay(
              row,
              previewUrlsByPath: previewUrlsByPath,
            ),
          )
          .toList(growable: false);
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
