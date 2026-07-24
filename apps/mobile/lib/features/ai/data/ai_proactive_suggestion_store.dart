import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_proactive_suggestion.dart';

final aiProactiveSuggestionStoreProvider = Provider<AiProactiveSuggestionStore>(
  (ref) => SharedPreferencesAiProactiveSuggestionStore(),
);

abstract interface class AiProactiveSuggestionStore {
  Future<AiProactiveSuggestion?> loadSuggestion(String userId);

  Future<void> saveSuggestion(String userId, AiProactiveSuggestion suggestion);

  Future<bool> hasShownInSession({
    required String userId,
    required String sessionId,
  });

  Future<void> markShown({
    required String userId,
    required String sessionId,
    required String contextDate,
  });
}

class SharedPreferencesAiProactiveSuggestionStore
    implements AiProactiveSuggestionStore {
  SharedPreferencesAiProactiveSuggestionStore({
    AiProactiveSuggestionPreferences? preferences,
  }) : _preferences =
           preferences ?? SharedPreferencesAiProactiveSuggestionPreferences();

  static const _suggestionPrefix = 'vinscent.ai.proactive.suggestion';
  static const _impressionPrefix = 'vinscent.ai.proactive.impressions';

  final AiProactiveSuggestionPreferences _preferences;

  @override
  Future<AiProactiveSuggestion?> loadSuggestion(String userId) async {
    final key = '$_suggestionPrefix.$userId';
    final encoded = await _preferences.getString(key);
    if (encoded == null) {
      return null;
    }

    try {
      return AiProactiveSuggestion.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } on Object {
      await _preferences.remove(key);
      return null;
    }
  }

  @override
  Future<void> saveSuggestion(String userId, AiProactiveSuggestion suggestion) {
    return _preferences.setString(
      '$_suggestionPrefix.$userId',
      jsonEncode(suggestion.toJson()),
    );
  }

  @override
  Future<bool> hasShownInSession({
    required String userId,
    required String sessionId,
  }) async {
    final record = await _loadImpressions(userId);
    return record.sessionIds.contains(sessionId);
  }

  @override
  Future<void> markShown({
    required String userId,
    required String sessionId,
    required String contextDate,
  }) async {
    final record = await _loadImpressions(userId);
    final sessionIds = record.contextDate == contextDate
        ? {...record.sessionIds}
        : <String>{};
    sessionIds.add(sessionId);
    await _preferences.setString(
      '$_impressionPrefix.$userId',
      jsonEncode({
        'context_date': contextDate,
        'session_ids': sessionIds.toList(growable: false),
      }),
    );
  }

  Future<_ProactiveImpressionRecord> _loadImpressions(String userId) async {
    final encoded = await _preferences.getString('$_impressionPrefix.$userId');
    if (encoded == null) {
      return const _ProactiveImpressionRecord(contextDate: '', sessionIds: {});
    }

    try {
      final data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      final contextDate = data['context_date'];
      final sessionIds = data['session_ids'];
      if (contextDate is! String || sessionIds is! List) {
        throw const FormatException('Invalid proactive impressions');
      }
      return _ProactiveImpressionRecord(
        contextDate: contextDate,
        sessionIds: sessionIds.whereType<String>().toSet(),
      );
    } on Object {
      return const _ProactiveImpressionRecord(contextDate: '', sessionIds: {});
    }
  }
}

abstract interface class AiProactiveSuggestionPreferences {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesAiProactiveSuggestionPreferences
    implements AiProactiveSuggestionPreferences {
  SharedPreferencesAiProactiveSuggestionPreferences({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client {
    return _preferences ??= SharedPreferencesAsync();
  }

  @override
  Future<String?> getString(String key) => _client.getString(key);

  @override
  Future<void> setString(String key, String value) {
    return _client.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _client.remove(key);
}

class _ProactiveImpressionRecord {
  const _ProactiveImpressionRecord({
    required this.contextDate,
    required this.sessionIds,
  });

  final String contextDate;
  final Set<String> sessionIds;
}
