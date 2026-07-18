import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/widget_recording_upload_task.dart';
import 'package:vinscent/features/recordings/data/couple_recording_failure.dart';

void main() {
  group('WidgetRecordingUploadRequest', () {
    test('parses a valid native upload request', () {
      final request = WidgetRecordingUploadRequest.fromArguments({
        'filePath': '/data/user/0/com.vinscent.vinscent/files/pending.m4a',
        'durationMs': 4200,
        'recordingId': '9f90dbff-7f06-4d06-ae53-b5e8762c83af',
      });

      expect(request.filePath, endsWith('pending.m4a'));
      expect(request.durationMs, 4200);
      expect(request.recordingId, '9f90dbff-7f06-4d06-ae53-b5e8762c83af');
    });

    test('rejects an empty path and an out-of-range duration', () {
      expect(
        () => WidgetRecordingUploadRequest.fromArguments({
          'filePath': '',
          'durationMs': 0,
        }),
        throwsFormatException,
      );
      expect(
        () => WidgetRecordingUploadRequest.fromArguments({
          'filePath': '/tmp/pending.m4a',
          'durationMs': 15001,
        }),
        throwsFormatException,
      );
    });
  });

  test(
    'uploads the draft before replacing the widget playback cache',
    () async {
      final events = <String>[];
      final reader = _FakeDraftReader(
        Uint8List.fromList([1, 2, 3]),
        onRead: () => events.add('read'),
      );
      final gateway = _FakeUploadGateway(
        onUpload: (bytes, durationMs) {
          expect(bytes, [1, 2, 3]);
          expect(durationMs, 4200);
          events.add('upload');
        },
      );
      final cache = _FakePlaybackCache(
        onReplace: (bytes) {
          expect(bytes, [1, 2, 3]);
          events.add('cache');
        },
      );
      final task = WidgetRecordingUploadTask(
        draftReader: reader,
        uploadGateway: gateway,
        playbackCache: cache,
      );

      await task.execute(
        const WidgetRecordingUploadRequest(
          filePath: '/tmp/pending.m4a',
          durationMs: 4200,
        ),
      );

      expect(events, ['read', 'upload', 'cache']);
    },
  );

  test('does not replace the playback cache when upload fails', () async {
    final cache = _FakePlaybackCache();
    final task = WidgetRecordingUploadTask(
      draftReader: _FakeDraftReader(Uint8List.fromList([1])),
      uploadGateway: _FakeUploadGateway(
        error: const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.authRequired,
        ),
      ),
      playbackCache: cache,
    );

    await expectLater(
      task.execute(
        const WidgetRecordingUploadRequest(
          filePath: '/tmp/pending.m4a',
          durationMs: 1000,
        ),
      ),
      throwsA(isA<CoupleRecordingRepositoryException>()),
    );
    expect(cache.replaceCount, 0);
  });

  test(
    'keeps a completed upload successful when local cache refresh fails',
    () async {
      final gateway = _FakeUploadGateway();
      final task = WidgetRecordingUploadTask(
        draftReader: _FakeDraftReader(Uint8List.fromList([1])),
        uploadGateway: gateway,
        playbackCache: _FakePlaybackCache(error: StateError('cache failed')),
      );

      await task.execute(
        const WidgetRecordingUploadRequest(
          filePath: '/tmp/pending.m4a',
          durationMs: 1000,
        ),
      );

      expect(gateway.uploadCount, 1);
    },
  );

  test('only transient recording failures are retryable', () {
    expect(
      isRetryableWidgetRecordingUploadError(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.requestTimeout,
        ),
      ),
      isTrue,
    );
    expect(
      isRetryableWidgetRecordingUploadError(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.storage,
        ),
      ),
      isTrue,
    );
    expect(
      isRetryableWidgetRecordingUploadError(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.authRequired,
        ),
      ),
      isFalse,
    );
  });
}

class _FakeDraftReader implements WidgetRecordingDraftReader {
  _FakeDraftReader(this.bytes, {this.onRead});

  final Uint8List bytes;
  final void Function()? onRead;

  @override
  Future<Uint8List> read(String filePath) async {
    onRead?.call();
    return bytes;
  }
}

class _FakeUploadGateway implements WidgetRecordingUploadGateway {
  _FakeUploadGateway({this.onUpload, this.error});

  final void Function(Uint8List bytes, int durationMs)? onUpload;
  final Object? error;
  int uploadCount = 0;

  @override
  Future<void> upload(
    Uint8List bytes, {
    required int durationMs,
    String? recordingId,
  }) async {
    uploadCount += 1;
    final uploadError = error;
    if (uploadError != null) {
      throw uploadError;
    }
    onUpload?.call(bytes, durationMs);
  }
}

class _FakePlaybackCache implements WidgetRecordingPlaybackCache {
  _FakePlaybackCache({this.onReplace, this.error});

  final void Function(Uint8List bytes)? onReplace;
  final Object? error;
  int replaceCount = 0;

  @override
  Future<void> replace(Uint8List bytes) async {
    replaceCount += 1;
    final cacheError = error;
    if (cacheError != null) {
      throw cacheError;
    }
    onReplace?.call(bytes);
  }
}
