import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_cache_manifest.dart';

void main() {
  group('HomeWidgetRecordingCacheManifest', () {
    test('round-trips a verified cache manifest through JSON', () {
      const manifest = HomeWidgetRecordingCacheManifest.verified(
        coupleId: 'couple-a',
        recordingId: 'recording-a',
        revision: 3,
        audioPath: '/cache/recording-a.m4a',
        fileKey: 'widget_recording_recording-a',
        generation: 7,
      );

      final restored = HomeWidgetRecordingCacheManifest.tryParse(
        manifest.toJsonString(),
      );

      expect(restored, manifest);
      expect(HomeWidgetRecordingCachePolicy.canUseCached(restored), isTrue);
    });

    test('allows a required recording when the cached id already matches', () {
      const manifest = HomeWidgetRecordingCacheManifest.required(
        coupleId: 'couple-a',
        requiredRecordingId: 'recording-a',
        cachedRecordingId: 'recording-a',
        cachedRevision: 2,
        audioPath: '/cache/recording-a.m4a',
        fileKey: 'widget_recording_recording-a',
        generation: 4,
      );

      expect(HomeWidgetRecordingCachePolicy.canUseCached(manifest), isTrue);
    });

    test('blocks a stale cache when a different recording is required', () {
      const manifest = HomeWidgetRecordingCacheManifest.required(
        coupleId: 'couple-a',
        requiredRecordingId: 'recording-b',
        cachedRecordingId: 'recording-a',
        cachedRevision: 2,
        audioPath: '/cache/recording-a.m4a',
        fileKey: 'widget_recording_recording-a',
        generation: 5,
      );

      expect(HomeWidgetRecordingCachePolicy.canUseCached(manifest), isFalse);
    });

    test('blocks an unverified cache when a server refresh is required', () {
      const manifest = HomeWidgetRecordingCacheManifest.refreshRequired(
        coupleId: 'couple-a',
        cachedRecordingId: 'recording-a',
        cachedRevision: 2,
        audioPath: '/cache/recording-a.m4a',
        fileKey: 'widget_recording_recording-a',
        generation: 6,
      );

      expect(HomeWidgetRecordingCachePolicy.canUseCached(manifest), isFalse);
    });

    test(
      'preserves the current file while marking a newer recording required',
      () {
        const current = HomeWidgetRecordingCacheManifest.verified(
          coupleId: 'couple-a',
          recordingId: 'recording-a',
          revision: 1,
          audioPath: '/cache/recording-a.m4a',
          fileKey: 'widget_recording_recording-a',
          generation: 8,
        );

        final marked = HomeWidgetRecordingCachePolicy.markRequired(
          current: current,
          coupleId: 'couple-a',
          recordingId: 'recording-b',
        );

        expect(marked.requiredRecordingId, 'recording-b');
        expect(marked.cachedRecordingId, 'recording-a');
        expect(marked.audioPath, '/cache/recording-a.m4a');
        expect(marked.generation, 9);
        expect(HomeWidgetRecordingCachePolicy.canUseCached(marked), isFalse);
      },
    );

    test('drops a previous couple cache when a new couple marker arrives', () {
      const current = HomeWidgetRecordingCacheManifest.verified(
        coupleId: 'couple-a',
        recordingId: 'recording-a',
        revision: 1,
        audioPath: '/cache/recording-a.m4a',
        fileKey: 'widget_recording_recording-a',
        generation: 2,
      );

      final marked = HomeWidgetRecordingCachePolicy.markRequired(
        current: current,
        coupleId: 'couple-b',
        recordingId: 'recording-b',
      );

      expect(marked.coupleId, 'couple-b');
      expect(marked.cachedRecordingId, isNull);
      expect(marked.audioPath, isNull);
      expect(marked.requiredRecordingId, 'recording-b');
      expect(HomeWidgetRecordingCachePolicy.canUseCached(marked), isFalse);
    });

    test(
      'rejects a fetch result when a newer marker changed the generation',
      () {
        const expected = HomeWidgetRecordingCacheManifest.required(
          coupleId: 'couple-a',
          requiredRecordingId: 'recording-a',
          generation: 10,
        );
        const current = HomeWidgetRecordingCacheManifest.required(
          coupleId: 'couple-a',
          requiredRecordingId: 'recording-b',
          generation: 11,
        );

        expect(
          HomeWidgetRecordingCachePolicy.canCommitFetched(
            expected: expected,
            current: current,
          ),
          isFalse,
        );
      },
    );
  });
}
