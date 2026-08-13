import 'dart:convert';

enum HomeWidgetRecordingCacheFreshness {
  verified('verified'),
  required('required'),
  refreshRequired('refresh_required');

  const HomeWidgetRecordingCacheFreshness(this.serializedValue);

  final String serializedValue;

  static HomeWidgetRecordingCacheFreshness? fromSerialized(String value) {
    for (final freshness in values) {
      if (freshness.serializedValue == value) {
        return freshness;
      }
    }
    return null;
  }
}

class HomeWidgetRecordingCacheManifest {
  const HomeWidgetRecordingCacheManifest.verified({
    required this.coupleId,
    required String recordingId,
    required int revision,
    required this.audioPath,
    required this.fileKey,
    required this.generation,
  }) : freshness = HomeWidgetRecordingCacheFreshness.verified,
       cachedRecordingId = recordingId,
       cachedRevision = revision,
       requiredRecordingId = null;

  const HomeWidgetRecordingCacheManifest.required({
    required this.coupleId,
    required this.requiredRecordingId,
    required this.generation,
    this.cachedRecordingId,
    this.cachedRevision,
    this.audioPath,
    this.fileKey,
  }) : freshness = HomeWidgetRecordingCacheFreshness.required;

  const HomeWidgetRecordingCacheManifest.refreshRequired({
    required this.coupleId,
    required this.generation,
    this.cachedRecordingId,
    this.cachedRevision,
    this.audioPath,
    this.fileKey,
  }) : freshness = HomeWidgetRecordingCacheFreshness.refreshRequired,
       requiredRecordingId = null;

  const HomeWidgetRecordingCacheManifest._({
    required this.coupleId,
    required this.freshness,
    required this.generation,
    this.cachedRecordingId,
    this.cachedRevision,
    this.audioPath,
    this.fileKey,
    this.requiredRecordingId,
  });

  static const schemaVersion = 1;

  final String coupleId;
  final String? cachedRecordingId;
  final int? cachedRevision;
  final String? audioPath;
  final String? fileKey;
  final HomeWidgetRecordingCacheFreshness freshness;
  final String? requiredRecordingId;
  final int generation;

  String toJsonString() {
    return jsonEncode({
      'schemaVersion': schemaVersion,
      'coupleId': coupleId,
      'cachedRecordingId': cachedRecordingId,
      'cachedRevision': cachedRevision,
      'audioPath': audioPath,
      'fileKey': fileKey,
      'freshness': freshness.serializedValue,
      'requiredRecordingId': requiredRecordingId,
      'generation': generation,
    });
  }

  static HomeWidgetRecordingCacheManifest? tryParse(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != schemaVersion) {
        return null;
      }

      final coupleId = _nonEmptyString(decoded['coupleId']);
      final freshnessValue = _nonEmptyString(decoded['freshness']);
      final freshness = freshnessValue == null
          ? null
          : HomeWidgetRecordingCacheFreshness.fromSerialized(freshnessValue);
      final generation = decoded['generation'];
      if (coupleId == null ||
          freshness == null ||
          generation is! int ||
          generation < 0) {
        return null;
      }

      final manifest = HomeWidgetRecordingCacheManifest._(
        coupleId: coupleId,
        cachedRecordingId: _nonEmptyString(decoded['cachedRecordingId']),
        cachedRevision: _nonNegativeInt(decoded['cachedRevision']),
        audioPath: _nonEmptyString(decoded['audioPath']),
        fileKey: _nonEmptyString(decoded['fileKey']),
        freshness: freshness,
        requiredRecordingId: _nonEmptyString(decoded['requiredRecordingId']),
        generation: generation,
      );
      return manifest._isValid ? manifest : null;
    } on FormatException {
      return null;
    }
  }

  bool get _hasCompleteCache =>
      cachedRecordingId != null &&
      cachedRevision != null &&
      audioPath != null &&
      fileKey != null;

  bool get _isValid {
    return switch (freshness) {
      HomeWidgetRecordingCacheFreshness.verified =>
        _hasCompleteCache && requiredRecordingId == null,
      HomeWidgetRecordingCacheFreshness.required =>
        requiredRecordingId != null &&
            (_hasCompleteCache ||
                (cachedRecordingId == null &&
                    cachedRevision == null &&
                    audioPath == null &&
                    fileKey == null)),
      HomeWidgetRecordingCacheFreshness.refreshRequired =>
        requiredRecordingId == null &&
            (_hasCompleteCache ||
                (cachedRecordingId == null &&
                    cachedRevision == null &&
                    audioPath == null &&
                    fileKey == null)),
    };
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int? _nonNegativeInt(Object? value) {
    return value is int && value >= 0 ? value : null;
  }

  @override
  bool operator ==(Object other) {
    return other is HomeWidgetRecordingCacheManifest &&
        other.coupleId == coupleId &&
        other.cachedRecordingId == cachedRecordingId &&
        other.cachedRevision == cachedRevision &&
        other.audioPath == audioPath &&
        other.fileKey == fileKey &&
        other.freshness == freshness &&
        other.requiredRecordingId == requiredRecordingId &&
        other.generation == generation;
  }

  @override
  int get hashCode => Object.hash(
    coupleId,
    cachedRecordingId,
    cachedRevision,
    audioPath,
    fileKey,
    freshness,
    requiredRecordingId,
    generation,
  );
}

class HomeWidgetRecordingCachePolicy {
  const HomeWidgetRecordingCachePolicy._();

  static bool canUseCached(HomeWidgetRecordingCacheManifest? manifest) {
    if (manifest == null || !manifest._hasCompleteCache) {
      return false;
    }

    return switch (manifest.freshness) {
      HomeWidgetRecordingCacheFreshness.verified => true,
      HomeWidgetRecordingCacheFreshness.required =>
        manifest.requiredRecordingId == manifest.cachedRecordingId,
      HomeWidgetRecordingCacheFreshness.refreshRequired => false,
    };
  }

  static HomeWidgetRecordingCacheManifest markRequired({
    required HomeWidgetRecordingCacheManifest? current,
    required String coupleId,
    required String recordingId,
  }) {
    final nextGeneration = (current?.generation ?? 0) + 1;
    if (current?.coupleId != coupleId) {
      return HomeWidgetRecordingCacheManifest.required(
        coupleId: coupleId,
        requiredRecordingId: recordingId,
        generation: nextGeneration,
      );
    }

    if (current?.cachedRecordingId == recordingId &&
        current?._hasCompleteCache == true) {
      return HomeWidgetRecordingCacheManifest.verified(
        coupleId: coupleId,
        recordingId: recordingId,
        revision: current!.cachedRevision!,
        audioPath: current.audioPath!,
        fileKey: current.fileKey!,
        generation: nextGeneration,
      );
    }

    return HomeWidgetRecordingCacheManifest.required(
      coupleId: coupleId,
      requiredRecordingId: recordingId,
      cachedRecordingId: current?.cachedRecordingId,
      cachedRevision: current?.cachedRevision,
      audioPath: current?.audioPath,
      fileKey: current?.fileKey,
      generation: nextGeneration,
    );
  }

  static bool canCommitFetched({
    required HomeWidgetRecordingCacheManifest? expected,
    required HomeWidgetRecordingCacheManifest? current,
  }) {
    if (expected == null) {
      return current == null;
    }
    return expected != null &&
        current != null &&
        expected.coupleId == current.coupleId &&
        expected.generation == current.generation;
  }
}
