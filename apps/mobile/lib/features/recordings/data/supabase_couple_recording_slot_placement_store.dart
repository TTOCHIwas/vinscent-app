import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_recording_data_gateways.dart';
import 'couple_recording_failure.dart';
import 'supabase_couple_recording_gateway_support.dart';

class SupabaseCoupleRecordingSlotPlacementStore
    implements CoupleRecordingSlotPlacementStore {
  const SupabaseCoupleRecordingSlotPlacementStore({
    SupabaseCoupleRecordingGatewaySupport support =
        const SupabaseCoupleRecordingGatewaySupport(),
  }) : _support = support;

  final SupabaseCoupleRecordingGatewaySupport _support;

  @override
  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) async {
    _support.ensureConfigured();

    try {
      await _support.client
          .rpc(
            'upsert_couple_recording_slot_placement',
            params: {
              'requested_slot_id': slotId,
              'requested_normalized_x': normalizedX,
              'requested_normalized_y': normalizedY,
              'expected_placement_revision': expectedPlacementRevision,
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
  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  }) async {
    _support.ensureConfigured();

    try {
      await _support.client
          .rpc(
            'delete_couple_recording_slot_placement',
            params: {
              'requested_slot_id': slotId,
              'expected_placement_revision': expectedPlacementRevision,
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
}
