import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_recording.dart';
import 'couple_recording_data_gateways.dart';
import 'couple_recording_failure.dart';
import 'couple_recording_read_mapper.dart';
import 'supabase_couple_recording_gateway_support.dart';

class SupabaseCoupleRecordingOverviewReader
    implements CoupleRecordingOverviewReader {
  const SupabaseCoupleRecordingOverviewReader({
    SupabaseCoupleRecordingGatewaySupport support =
        const SupabaseCoupleRecordingGatewaySupport(),
    CoupleRecordingReadMapper readMapper = const CoupleRecordingReadMapper(),
  }) : _support = support,
       _readMapper = readMapper;

  final SupabaseCoupleRecordingGatewaySupport _support;
  final CoupleRecordingReadMapper _readMapper;

  @override
  Future<CoupleRecordingOverview> fetchOverview() async {
    _support.ensureConfigured();

    try {
      final currentData = await _support.client
          .rpc('get_current_couple_recording')
          .timeout(AppConfig.supabaseRpcTimeout);
      final currentRow = _support.asSingleRow(currentData);
      if (currentRow == null) {
        throw const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.unknown,
        );
      }

      final slotData = await _support.client
          .rpc('list_couple_recording_slots')
          .timeout(AppConfig.supabaseRpcTimeout);
      final slotRows = _support.asRows(slotData);

      final currentRecording = await _readMapper.mapCurrentRecording(
        currentRow,
        resolveAudioUrl: _support.createRecordingSignedUrl,
      );
      final savedSlots = await Future.wait(
        slotRows.map(
          (row) => _readMapper.mapSavedSlot(
            row,
            resolveAudioUrl: _support.createRecordingSignedUrl,
            resolveArtworkUrl: _support.createArtworkSignedUrl,
          ),
        ),
      );

      return CoupleRecordingOverview(
        slotLimit: currentRow['slot_limit'] as int,
        currentRecording: currentRecording,
        savedSlots: savedSlots,
      );
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _support.mapPostgrestError(error);
    } on StorageException catch (error) {
      throw _support.mapStorageError(error);
    }
  }
}
