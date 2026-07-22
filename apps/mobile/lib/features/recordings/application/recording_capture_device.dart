import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

abstract interface class RecordingCaptureDevice {
  Future<bool> hasPermission();

  Future<void> start({required String path});

  Future<String?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

typedef RecordingCaptureDeviceFactory = RecordingCaptureDevice Function();

final recordingCaptureDeviceFactoryProvider =
    Provider<RecordingCaptureDeviceFactory>(
      (_) => _RecordRecordingCaptureDevice.new,
    );

class _RecordRecordingCaptureDevice implements RecordingCaptureDevice {
  static const _config = RecordConfig(encoder: AudioEncoder.aacLc);

  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() {
    return _recorder.hasPermission();
  }

  @override
  Future<void> start({required String path}) {
    return _recorder.start(_config, path: path);
  }

  @override
  Future<String?> stop() {
    return _recorder.stop();
  }

  @override
  Future<void> cancel() {
    return _recorder.cancel();
  }

  @override
  Future<void> dispose() {
    return _recorder.dispose();
  }
}
