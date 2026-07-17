import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/recording_playback_controller.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';

void main() {
  group('RecordingPlaybackController', () {
    test('재생 완료를 기다리는 동안에도 같은 홈 슬롯을 일시정지할 수 있다', () async {
      final player = _FakeRecordingAudioPlayer();
      final harness = _PlaybackHarness(player);
      addTearDown(harness.dispose);
      final target = RecordingPlaybackTarget.homeSlot(_slot(1));

      await harness.controller.toggle(target).timeout(_operationTimeout);

      expect(player.hasPendingPlayback, isTrue);
      expect(harness.state.isPlaying, isTrue);
      expect(harness.state.isBusy, isFalse);

      await harness.controller.toggle(target).timeout(_operationTimeout);

      expect(player.pauseCount, 1);
      expect(harness.state.isPlaying, isFalse);
      expect(harness.state.isBusy, isFalse);
    });

    test('재생 완료를 기다리는 동안에도 다른 홈 슬롯으로 전환할 수 있다', () async {
      final player = _FakeRecordingAudioPlayer();
      final harness = _PlaybackHarness(player);
      addTearDown(harness.dispose);
      final firstTarget = RecordingPlaybackTarget.homeSlot(_slot(1));
      final secondTarget = RecordingPlaybackTarget.homeSlot(_slot(2));

      await harness.controller.toggle(firstTarget).timeout(_operationTimeout);
      await harness.controller.toggle(secondTarget).timeout(_operationTimeout);

      expect(player.loadedUrls, [
        'https://example.com/audio-1.m4a',
        'https://example.com/audio-2.m4a',
      ]);
      expect(player.playCount, 2);
      expect(player.hasPendingPlayback, isTrue);
      expect(harness.state.activeTargetKey, secondTarget.key);
      expect(harness.state.isPlaying, isTrue);
      expect(harness.state.isBusy, isFalse);
    });
  });
}

const _operationTimeout = Duration(seconds: 1);

class _PlaybackHarness {
  _PlaybackHarness(RecordingAudioPlayer player)
    : container = ProviderContainer(
        overrides: [
          recordingAudioPlayerFactoryProvider.overrideWithValue(() => player),
        ],
      ) {
    subscription = container.listen(provider, (_, _) {}, fireImmediately: true);
    controller = container.read(provider.notifier);
  }

  final ProviderContainer container;
  final provider = recordingPlaybackControllerProvider(
    RecordingPlaybackSurface.home,
  );
  late final ProviderSubscription<RecordingPlaybackState> subscription;
  late final RecordingPlaybackController controller;

  RecordingPlaybackState get state => container.read(provider);

  void dispose() {
    subscription.close();
    container.dispose();
  }
}

class _FakeRecordingAudioPlayer implements RecordingAudioPlayer {
  final _states = StreamController<RecordingAudioPlayerState>.broadcast(
    sync: true,
  );
  final loadedUrls = <String>[];

  Completer<void>? _playbackCompletion;
  bool _playing = false;
  bool _completed = false;
  int playCount = 0;
  int pauseCount = 0;

  bool get hasPendingPlayback =>
      _playbackCompletion != null && !_playbackCompletion!.isCompleted;

  @override
  Stream<RecordingAudioPlayerState> get stateStream => _states.stream;

  @override
  bool get playing => _playing;

  @override
  bool get completed => _completed;

  @override
  Future<void> load(String audioUrl) async {
    loadedUrls.add(audioUrl);
  }

  @override
  Future<void> play() {
    playCount += 1;
    _playing = true;
    _completed = false;
    _playbackCompletion = Completer<void>();
    _emitState();
    return _playbackCompletion!.future;
  }

  @override
  Future<void> pause() async {
    pauseCount += 1;
    _playing = false;
    _completePlayback();
    _emitState();
  }

  @override
  Future<void> seek(Duration position) async {
    _completed = false;
    _emitState();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _completed = false;
    _completePlayback();
    _emitState();
  }

  @override
  Future<void> dispose() async {
    _completePlayback();
    await _states.close();
  }

  void _completePlayback() {
    final completion = _playbackCompletion;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
  }

  void _emitState() {
    if (_states.isClosed) {
      return;
    }
    _states.add(
      RecordingAudioPlayerState(playing: _playing, completed: _completed),
    );
  }
}

CoupleRecordingSlot _slot(int index) {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CoupleRecordingSlot(
    slotId: 'slot-$index',
    slotIndex: index,
    title: '녹음 $index',
    recordingId: 'recording-$index',
    senderUserId: 'user-id',
    durationMs: 1000,
    recordedAt: timestamp,
    slotRevision: 1,
    createdByUserId: 'user-id',
    updatedByUserId: 'user-id',
    createdAt: timestamp,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/audio-$index.m4a',
  );
}
