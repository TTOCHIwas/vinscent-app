import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/date/app_date_policy.dart';
import '../../../core/storage/signed_url_cache.dart';
import 'couple_calendar_event.dart';
import 'couple_calendar_event_artwork_path.dart';
import 'couple_calendar_event_data_gateways.dart';
import 'couple_calendar_event_failure.dart';
import 'couple_calendar_event_mapper.dart';
import 'couple_calendar_event_repository_contract.dart';

class SupabaseCoupleCalendarEventGateway implements CoupleCalendarEventGateway {
  const SupabaseCoupleCalendarEventGateway({
    required SignedUrlCache signedUrlCache,
    CoupleCalendarEventMapper mapper = const CoupleCalendarEventMapper(),
  }) : _signedUrlCache = signedUrlCache,
       _mapper = mapper;

  static const _signedUrlExpiresInSeconds = 60 * 60;

  final CoupleCalendarEventMapper _mapper;
  final SignedUrlCache _signedUrlCache;

  @override
  Future<bool> hasOccurrenceOn(DateTime date) async {
    _ensureConfigured();

    try {
      final data = await _client
          .rpc(
            'has_couple_calendar_event_occurrence',
            params: {'target_date': formatCalendarDate(date)},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      if (data is bool) {
        return data;
      }
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.unknown,
      );
    } on TimeoutException {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw mapCalendarEventPostgrestError(error);
    }
  }

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _ensureConfigured();

    try {
      final data = await _client
          .rpc(
            'get_couple_calendar_event_occurrences',
            params: {
              'target_start_date': formatCalendarDate(startDate),
              'target_end_date': formatCalendarDate(endDate),
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      return _mapRowsWithSignedPreviews(_asRows(data));
    } on TimeoutException {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw mapCalendarEventPostgrestError(error);
    }
  }

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) async {
    _ensureConfigured();

    try {
      final data = await _client
          .rpc(
            'get_couple_calendar_event',
            params: {'requested_event_id': eventId},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      final rows = _asRows(data);
      if (rows.isEmpty) {
        return null;
      }
      return (await _mapRowsWithSignedPreviews([rows.first])).first;
    } on TimeoutException {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw mapCalendarEventPostgrestError(error);
    }
  }

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required CoupleCalendarEventSaveRequest request,
    required String? artworkRevision,
  }) async {
    _ensureConfigured();

    try {
      final data = await _client
          .rpc(
            'save_couple_calendar_event',
            params: {
              'requested_event_id': request.eventId,
              'requested_title': request.title,
              'requested_event_date': formatCalendarDate(request.eventDate),
              'requested_repeat_rule': request.repeatRule.toJson(),
              'requested_memo': request.memo,
              'requested_artwork_revision': artworkRevision,
              'requested_remove_artwork': request.removeArtwork,
              'requested_reminder_enabled': request.reminder.isEnabled,
              'requested_reminder_offset_days': request.reminder.offsetDays,
              'requested_reminder_time': request.reminder.serializedTime,
              'expected_event_revision': request.expectedRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      final rows = _asRows(data);
      if (rows.length != 1) {
        throw const CoupleCalendarEventRepositoryException(
          CoupleCalendarEventFailureReason.unknown,
        );
      }
      return (await _mapRowsWithSignedPreviews(rows)).single;
    } on TimeoutException {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw mapCalendarEventPostgrestError(error);
    }
  }

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) async {
    _ensureConfigured();

    try {
      await _client
          .rpc(
            'delete_couple_calendar_event',
            params: {
              'requested_event_id': eventId,
              'expected_event_revision': expectedRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw mapCalendarEventPostgrestError(error);
    }
  }

  Future<List<CoupleCalendarEvent>> _mapRowsWithSignedPreviews(
    List<Map<String, dynamic>> rows,
  ) async {
    final paths = rows
        .map((row) => row['artwork_preview_path'])
        .whereType<String>()
        .toSet()
        .toList(growable: false);
    final previewUrlsByPath = await _createPreviewUrlsByPath(paths);
    return rows
        .map(
          (row) =>
              _mapper.mapOccurrence(row, previewUrlsByPath: previewUrlsByPath),
        )
        .toList(growable: false);
  }

  Future<Map<String, String>> _createPreviewUrlsByPath(
    List<String> paths,
  ) async {
    if (paths.isEmpty) {
      return const {};
    }

    try {
      return _signedUrlCache.resolve(
        bucketId: CoupleCalendarEventArtworkPath.bucketId,
        paths: paths,
        expiresInSeconds: _signedUrlExpiresInSeconds,
        loader: (missingPaths, expiresInSeconds) async {
          final signedUrls = await _client.storage
              .from(CoupleCalendarEventArtworkPath.bucketId)
              .createSignedUrls(missingPaths, expiresInSeconds)
              .timeout(AppConfig.supabaseRpcTimeout);
          return {
            for (final value in signedUrls)
              if (value.path.isNotEmpty) value.path: value.signedUrl,
          };
        },
      );
    } on TimeoutException {
      return const {};
    } on StorageException {
      return const {};
    }
  }

  List<Map<String, dynamic>> _asRows(Object? data) {
    if (data == null) {
      return const [];
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    if (data is Map) {
      return [Map<String, dynamic>.from(data)];
    }
    throw const CoupleCalendarEventRepositoryException(
      CoupleCalendarEventFailureReason.unknown,
    );
  }

  SupabaseClient get _client => Supabase.instance.client;

  void _ensureConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleCalendarEventRepositoryException(
        CoupleCalendarEventFailureReason.configMissing,
      );
    }
  }
}
