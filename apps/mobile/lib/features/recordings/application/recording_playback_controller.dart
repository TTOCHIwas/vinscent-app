import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/couple_recording.dart';

class RecordingAudioPlayerState {
  const RecordingAudioPlayerState({
    required this.playing,
    required this.completed,
  });

  final bool playing;
  final bool completed;

  bool get isPlaying => playing && !completed;
}

abstract interface class RecordingAudioPlayer {
  Stream<RecordingAudioPlayerState> get stateStream;
  bool get playing;
  bool get completed;

  Future<void> load(String audioUrl);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

typedef RecordingAudioPlayerFactory = RecordingAudioPlayer Function();

final recordingAudioPlayerFactoryProvider =
    Provider<RecordingAudioPlayerFactory>(
      (_) => _JustAudioRecordingAudioPlayer.new,
    );

class _JustAudioRecordingAudioPlayer implements RecordingAudioPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Stream<RecordingAudioPlayerState> get stateStream =>
      _player.playerStateStream.map(
        (state) => RecordingAudioPlayerState(
          playing: state.playing,
          completed: state.processingState == ProcessingState.completed,
        ),
      );

  @override
  bool get playing => _player.playing;

  @override
  bool get completed => _player.processingState == ProcessingState.completed;

  @override
  Future<void> load(String audioUrl) async {
    await _player.setUrl(audioUrl);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

enum RecordingPlaybackSurface { home, library }

class RecordingPlaybackTarget {
  const RecordingPlaybackTarget._({required this.key, required this.audioUrl});

  factory RecordingPlaybackTarget.homeCurrent(
    CurrentCoupleRecording recording,
  ) {
    return RecordingPlaybackTarget._(
      key: 'home-current:${recording.recordingId}',
      audioUrl: recording.audioUrl,
    );
  }

  factory RecordingPlaybackTarget.libraryCurrent(
    CurrentCoupleRecording recording,
  ) {
    return RecordingPlaybackTarget._(
      key: 'library-current:${recording.recordingId}',
      audioUrl: recording.audioUrl,
    );
  }

  factory RecordingPlaybackTarget.librarySlot(CoupleRecordingSlot slot) {
    return RecordingPlaybackTarget._(
      key: 'library-slot:${slot.slotId}:${slot.recordingId}',
      audioUrl: slot.audioUrl,
    );
  }

  factory RecordingPlaybackTarget.homeSlot(CoupleRecordingSlot slot) {
    return RecordingPlaybackTarget._(
      key: 'home-slot:${slot.slotId}:${slot.recordingId}',
      audioUrl: slot.audioUrl,
    );
  }

  final String key;
  final String audioUrl;
}

class RecordingPlaybackState {
  const RecordingPlaybackState({
    required this.activeTargetKey,
    required this.isPlaying,
    required this.isBusy,
  });

  const RecordingPlaybackState.idle()
    : this(activeTargetKey: null, isPlaying: false, isBusy: false);

  final String? activeTargetKey;
  final bool isPlaying;
  final bool isBusy;

  RecordingPlaybackState copyWith({
    String? activeTargetKey,
    bool clearActiveTargetKey = false,
    bool? isPlaying,
    bool? isBusy,
  }) {
    return RecordingPlaybackState(
      activeTargetKey: clearActiveTargetKey
          ? null
          : activeTargetKey ?? this.activeTargetKey,
      isPlaying: isPlaying ?? this.isPlaying,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

final recordingPlaybackControllerProvider = NotifierProvider.autoDispose
    .family<
      RecordingPlaybackController,
      RecordingPlaybackState,
      RecordingPlaybackSurface
    >((_) => RecordingPlaybackController());

class RecordingPlaybackController extends Notifier<RecordingPlaybackState> {
  late final RecordingAudioPlayer _player;
  StreamSubscription<RecordingAudioPlayerState>? _playerStateSubscription;
  bool _isHandlingToggle = false;

  @override
  RecordingPlaybackState build() {
    _player = ref.read(recordingAudioPlayerFactoryProvider)();
    _playerStateSubscription = _player.stateStream.listen(
      _handlePlayerStateChanged,
    );
    ref.onDispose(() {
      _playerStateSubscription?.cancel();
      unawaited(_player.dispose());
    });
    return const RecordingPlaybackState.idle();
  }

  Future<void> toggle(RecordingPlaybackTarget target) async {
    if (_isHandlingToggle) {
      return;
    }

    _isHandlingToggle = true;
    state = state.copyWith(isBusy: true);

    try {
      if (state.activeTargetKey != target.key) {
        await _player.stop();
        await _player.load(target.audioUrl);
        if (!ref.mounted) {
          return;
        }

        state = state.copyWith(activeTargetKey: target.key);
        await _startPlayback();
        return;
      }

      if (_player.completed) {
        await _player.seek(Duration.zero);
        await _startPlayback();
        return;
      }

      if (_player.playing) {
        await _player.pause();
        return;
      }

      await _startPlayback();
    } finally {
      _isHandlingToggle = false;
      if (ref.mounted) {
        state = state.copyWith(isBusy: false);
      }
    }
  }

  Future<void> syncAvailableTargetKeys(Set<String> targetKeys) async {
    final activeTargetKey = state.activeTargetKey;
    if (activeTargetKey == null || targetKeys.contains(activeTargetKey)) {
      return;
    }

    await reset();
  }

  Future<void> reset() async {
    await _player.stop();
    if (!ref.mounted) {
      return;
    }

    state = const RecordingPlaybackState.idle();
  }

  Future<void> _startPlayback() async {
    final playbackStarted = _player.stateStream
        .firstWhere((playerState) => playerState.isPlaying)
        .then<void>((_) {});
    final playbackCompleted = _player.play();

    await Future.any<void>([playbackStarted, playbackCompleted]);
  }

  void _handlePlayerStateChanged(RecordingAudioPlayerState playerState) {
    if (!ref.mounted) {
      return;
    }

    final isPlaying = playerState.isPlaying;
    if (state.isPlaying == isPlaying) {
      return;
    }

    state = state.copyWith(isPlaying: isPlaying);
  }
}
