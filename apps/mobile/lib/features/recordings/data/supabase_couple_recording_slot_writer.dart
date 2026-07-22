import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../recording_debug_log.dart';
import 'couple_recording.dart';
import 'couple_recording_data_gateways.dart';
import 'couple_recording_failure.dart';
import 'supabase_couple_recording_gateway_support.dart';

class SupabaseCoupleRecordingSlotWriter implements CoupleRecordingSlotWriter {
  const SupabaseCoupleRecordingSlotWriter({
    SupabaseCoupleRecordingGatewaySupport support =
        const SupabaseCoupleRecordingGatewaySupport(),
  }) : _support = support;

  final SupabaseCoupleRecordingGatewaySupport _support;

  @override
  Future<CoupleRecordingSlotSaveResult> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {
    _support.ensureConfigured();

    try {
      final data = await _support.client
          .rpc(
            'save_current_couple_recording_to_slot',
            params: {
              'requested_slot_index': slotIndex,
              'requested_title': title,
              'expected_slot_revision': expectedSlotRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _support.asSingleRow(data);
      if (row == null) {
        throw const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.unknown,
        );
      }
      return CoupleRecordingSlotSaveResult.fromJson(row);
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _support.mapPostgrestError(error);
    }
  }

  @override
  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) async {
    _support.ensureConfigured();

    try {
      await _support.client
          .rpc(
            'delete_couple_recording_slot',
            params: {
              'requested_slot_id': slotId,
              'expected_slot_revision': expectedSlotRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _support.mapPostgrestError(error);
    }
  }

  @override
  Future<void> openNextSlot() async {
    _support.ensureConfigured();

    try {
      debugRecordingLog('Open slot RPC started');
      final response = await _support.client
          .rpc('open_next_couple_recording_slot')
          .timeout(AppConfig.supabaseRpcTimeout);
      debugRecordingLog('Open slot RPC completed: response=$response');
    } on TimeoutException {
      debugRecordingLog('Open slot RPC timed out');
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      final mappedError = _support.mapPostgrestError(error);
      debugRecordingLog(
        'Open slot RPC failed: '
        'code=${error.code}, message=${error.message}, details=${error.details}, '
        'hint=${error.hint}, mappedError=$mappedError',
      );
      throw mappedError;
    } catch (error) {
      debugRecordingLog('Open slot RPC failed with unexpected error: $error');
      rethrow;
    }
  }
}
