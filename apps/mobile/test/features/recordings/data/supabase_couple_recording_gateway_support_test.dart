import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';
import 'package:vinscent/features/recordings/data/supabase_couple_recording_gateway_support.dart';

void main() {
  const support = SupabaseCoupleRecordingGatewaySupport();

  test('normalizes single-row RPC responses', () {
    expect(support.asSingleRow(null), isNull);
    expect(support.asSingleRow({'id': 1}), {'id': 1});
    expect(
      support.asSingleRow([
        {'id': 2},
      ]),
      {'id': 2},
    );
    expect(support.asSingleRow([]), isNull);
    expect(
      () => support.asSingleRow('invalid'),
      throwsA(
        isA<CoupleRecordingRepositoryException>().having(
          (error) => error.reason,
          'reason',
          CoupleRecordingFailureReason.unknown,
        ),
      ),
    );
  });

  test('normalizes list and single-row RPC responses', () {
    expect(
      support.asRows([
        {'id': 1},
        {'id': 2},
      ]),
      [
        {'id': 1},
        {'id': 2},
      ],
    );
    expect(support.asRows({'id': 3}), [
      {'id': 3},
    ]);
    expect(support.asRows(null), isEmpty);
  });

  test('maps database contract errors without losing their message', () {
    const source = PostgrestException(
      message: 'recording_slot_conflict',
      code: 'P0001',
    );

    final mapped = support.mapPostgrestError(source);

    expect(mapped.reason, CoupleRecordingFailureReason.recordingSlotConflict);
    expect(mapped.message, source.message);
  });

  test('maps storage failures to the storage reason', () {
    const source = StorageException(
      'upload failed',
      error: 'StorageError',
      statusCode: '500',
    );

    final mapped = support.mapStorageError(source);

    expect(mapped.reason, CoupleRecordingFailureReason.storage);
    expect(mapped.message, source.message);
  });
}
