import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../data/couple_recording.dart';

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
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isHandlingToggle = false;

  @override
  RecordingPlaybackState build() {
    _player = AudioPlayer();
    _playerStateSubscription = _player.playerStateStream.listen(
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
        await _player.setUrl(target.audioUrl);
        if (!ref.mounted) {
          return;
        }

        state = state.copyWith(activeTargetKey: target.key);
        await _player.play();
        return;
      }

      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }

      if (_player.playing) {
        await _player.pause();
        return;
      }

      await _player.play();
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

  void _handlePlayerStateChanged(PlayerState playerState) {
    if (!ref.mounted) {
      return;
    }

    final isPlaying =
        playerState.playing &&
        playerState.processingState != ProcessingState.completed;
    if (state.isPlaying == isPlaying) {
      return;
    }

    state = state.copyWith(isPlaying: isPlaying);
  }
}
