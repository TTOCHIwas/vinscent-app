import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_snapshot_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';
import 'package:vinscent/features/recordings/data/couple_recording_repository_contract.dart';
import 'package:vinscent/features/recordings/data/supabase_couple_recording_gateway_support.dart';
import 'package:vinscent/features/recordings/data/supabase_couple_recording_overview_reader.dart';

void main() {
  for (final present in [true, false]) {
    test(
      'current-only read makes one RPC, recording present: $present',
      () async {
        final paths = <String>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          paths.add(request.uri.path);
          await request.drain<void>();
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              if (present) ...{
                'current_recording_id': 'recording',
                'current_recording_path': 'audio.m4a',
                'current_sender_user_id': 'sender',
                'current_duration_ms': 1000,
                'current_recorded_at': '2026-10-18T00:00:00Z',
                'current_revision': 2,
                'current_updated_at': '2026-10-18T00:00:00Z',
              },
              'slot_limit': 3,
            }),
          );
          await request.response.close();
        });
        final client = SupabaseClient(
          'http://127.0.0.1:${server.port}',
          'test-key',
        );
        addTearDown(client.dispose);
        final support = _Support(client);
        final reader = SupabaseCoupleRecordingOverviewReader(support: support);
        final recording = await reader.fetchCurrentRecording();
        expect(paths, ['/rest/v1/rpc/get_current_couple_recording']);
        expect(support.signedPaths, present ? ['audio.m4a'] : isEmpty);
        expect(recording?.recordingId, present ? 'recording' : null);
      },
    );
  }

  test(
    'widget uses the current-only capability and preserves failures',
    () async {
      final repository = _Repository();
      final loader = HomeWidgetRecordingAssetLoader(
        recordingRepository: repository,
      );
      expect(
        (await loader.fetch(coupleId: 'couple')).type,
        HomeWidgetAssetUpdateType.remove,
      );
      repository.recording = CurrentCoupleRecording(
        recordingId: 'recording',
        senderUserId: 'sender',
        durationMs: 1000,
        recordedAt: DateTime(2026),
        revision: 1,
        updatedAt: DateTime(2026),
        audioUrl: 'https://audit.invalid/audio',
      );
      expect(
        (await loader.fetch(coupleId: 'couple')).type,
        HomeWidgetAssetUpdateType.replace,
      );
      repository.fail = true;
      expect(
        (await loader.fetch(coupleId: 'couple')).type,
        HomeWidgetAssetUpdateType.preserve,
      );
      expect(repository.currentReads, 3);
      expect(repository.overviewReads, 0);
    },
  );
}

class _Support extends SupabaseCoupleRecordingGatewaySupport {
  _Support(this.client);
  @override
  final SupabaseClient client;
  final signedPaths = <String>[];
  @override
  void ensureConfigured() {}
  @override
  Future<String> createRecordingSignedUrl(String path) async {
    signedPaths.add(path);
    return 'https://audit.invalid/audio';
  }
}

class _Repository extends Fake
    implements CoupleRecordingRepository, CurrentCoupleRecordingReader {
  CurrentCoupleRecording? recording;
  var fail = false;
  var currentReads = 0;
  var overviewReads = 0;
  @override
  Future<CurrentCoupleRecording?> fetchCurrentRecording() async {
    currentReads++;
    if (fail) {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.unknown,
      );
    }
    return recording;
  }

  @override
  Future<CoupleRecordingOverview> fetchOverview() async {
    overviewReads++;
    throw StateError('Unnecessary overview read');
  }
}
