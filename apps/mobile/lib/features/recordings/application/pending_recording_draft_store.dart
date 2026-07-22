import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'recording_draft_file.dart';

final pendingRecordingDraftStoreProvider = Provider<PendingRecordingDraftStore>(
  (ref) => SharedPreferencesPendingRecordingDraftStore(),
);

typedef RecordingSupportDirectoryLoader = Future<Directory> Function();

class PendingRecordingDraft {
  const PendingRecordingDraft({
    required this.recordingId,
    required this.coupleId,
    required this.durationMs,
  });

  factory PendingRecordingDraft.fromJson(Map<String, dynamic> json) {
    final recordingId = json['recording_id'];
    final coupleId = json['couple_id'];
    final durationMs = json['duration_ms'];
    if (recordingId is! String ||
        !_uuidPattern.hasMatch(recordingId) ||
        coupleId is! String ||
        !_uuidPattern.hasMatch(coupleId) ||
        durationMs is! int ||
        durationMs <= 0) {
      throw const FormatException('Invalid pending recording draft.');
    }

    return PendingRecordingDraft(
      recordingId: recordingId,
      coupleId: coupleId,
      durationMs: durationMs,
    );
  }

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  final String recordingId;
  final String coupleId;
  final int durationMs;

  Map<String, dynamic> toJson() {
    return {
      'recording_id': recordingId,
      'couple_id': coupleId,
      'duration_ms': durationMs,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is PendingRecordingDraft &&
        other.recordingId == recordingId &&
        other.coupleId == coupleId &&
        other.durationMs == durationMs;
  }

  @override
  int get hashCode => Object.hash(recordingId, coupleId, durationMs);
}

abstract interface class PendingRecordingDraftStore {
  Future<String> createFilePath(String recordingId);

  Future<void> persist(PendingRecordingDraft draft);

  Future<PendingRecordingDraft?> load();

  Future<Uint8List> readAudioBytes(PendingRecordingDraft draft);

  Future<void> remove(PendingRecordingDraft draft);
}

abstract interface class PendingRecordingDraftMetadataStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> clear();
}

class SharedPreferencesPendingRecordingDraftMetadataStore
    implements PendingRecordingDraftMetadataStore {
  SharedPreferencesPendingRecordingDraftMetadataStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  static const _metadataKey = 'vinscent.recording.pending_upload';

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client {
    return _preferences ??= SharedPreferencesAsync();
  }

  @override
  Future<String?> read() => _client.getString(_metadataKey);

  @override
  Future<void> write(String value) {
    return _client.setString(_metadataKey, value);
  }

  @override
  Future<void> clear() => _client.remove(_metadataKey);
}

class SharedPreferencesPendingRecordingDraftStore
    implements PendingRecordingDraftStore {
  SharedPreferencesPendingRecordingDraftStore({
    PendingRecordingDraftMetadataStore? metadataStore,
    RecordingSupportDirectoryLoader? supportDirectoryLoader,
  }) : _metadataStore =
           metadataStore ??
           SharedPreferencesPendingRecordingDraftMetadataStore(),
       _supportDirectoryLoader =
           supportDirectoryLoader ?? getApplicationSupportDirectory;

  static const _directoryName = 'pending_recordings';

  final PendingRecordingDraftMetadataStore _metadataStore;
  final RecordingSupportDirectoryLoader _supportDirectoryLoader;

  @override
  Future<String> createFilePath(String recordingId) async {
    if (!PendingRecordingDraft._uuidPattern.hasMatch(recordingId)) {
      throw ArgumentError.value(recordingId, 'recordingId');
    }

    final supportDirectory = await _supportDirectoryLoader();
    final draftDirectory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}$_directoryName',
    );
    await draftDirectory.create(recursive: true);
    return '${draftDirectory.path}${Platform.pathSeparator}$recordingId.m4a';
  }

  @override
  Future<void> persist(PendingRecordingDraft draft) {
    return _metadataStore.write(jsonEncode(draft.toJson()));
  }

  @override
  Future<PendingRecordingDraft?> load() async {
    final encodedDraft = await _metadataStore.read();
    if (encodedDraft == null) {
      return null;
    }

    try {
      final json = jsonDecode(encodedDraft);
      if (json is! Map) {
        throw const FormatException('Invalid pending recording draft.');
      }
      final draft = PendingRecordingDraft.fromJson(
        Map<String, dynamic>.from(json),
      );
      final filePath = await createFilePath(draft.recordingId);
      if (!await File(filePath).exists()) {
        await _metadataStore.clear();
        return null;
      }
      return draft;
    } on FormatException {
      await _metadataStore.clear();
      return null;
    }
  }

  @override
  Future<Uint8List> readAudioBytes(PendingRecordingDraft draft) async {
    final filePath = await createFilePath(draft.recordingId);
    return File(filePath).readAsBytes();
  }

  @override
  Future<void> remove(PendingRecordingDraft draft) async {
    final filePath = await createFilePath(draft.recordingId);
    await deleteRecordingDraftFile(filePath);
    await _metadataStore.clear();
  }
}
