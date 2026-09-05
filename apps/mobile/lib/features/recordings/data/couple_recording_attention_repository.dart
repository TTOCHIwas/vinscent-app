import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_recording_failure.dart';
import 'supabase_couple_recording_gateway_support.dart';

final coupleRecordingAttentionRepositoryProvider =
    Provider<CoupleRecordingAttentionRepository>((ref) {
      return const SupabaseCoupleRecordingAttentionRepository();
    });

abstract interface class CoupleRecordingAttentionRepository {
  Future<bool> acknowledgeCurrentRecording({required String recordingId});

  Future<bool> acknowledgeSlotRecording({
    required String slotId,
    required String recordingId,
  });
}

class SupabaseCoupleRecordingAttentionRepository
    implements CoupleRecordingAttentionRepository {
  const SupabaseCoupleRecordingAttentionRepository({
    SupabaseCoupleRecordingGatewaySupport support =
        const SupabaseCoupleRecordingGatewaySupport(),
  }) : _support = support;

  final SupabaseCoupleRecordingGatewaySupport _support;

  @override
  Future<bool> acknowledgeCurrentRecording({required String recordingId}) {
    return _acknowledge(
      functionName: 'acknowledge_current_couple_recording',
      parameters: {'requested_recording_id': recordingId},
    );
  }

  @override
  Future<bool> acknowledgeSlotRecording({
    required String slotId,
    required String recordingId,
  }) {
    return _acknowledge(
      functionName: 'acknowledge_couple_recording_slot',
      parameters: {
        'requested_slot_id': slotId,
        'requested_recording_id': recordingId,
      },
    );
  }

  Future<bool> _acknowledge({
    required String functionName,
    required Map<String, Object> parameters,
  }) async {
    _support.ensureConfigured();

    try {
      final result = await _support.client
          .rpc(functionName, params: parameters)
          .timeout(AppConfig.supabaseRpcTimeout);
      return result == true;
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _support.mapPostgrestError(error);
    }
  }
}
