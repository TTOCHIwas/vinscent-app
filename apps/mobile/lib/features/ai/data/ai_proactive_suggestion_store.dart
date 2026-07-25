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

  Future<bool> hasDismissedInSession({
    required String userId,
    required String sessionId,
    required String contextDate,
  });

  Future<void> markDismissed({
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
  static const _dismissalPrefix = 'vinscent.ai.proactive.dismissals';

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
  Future<bool> hasDismissedInSession({
    required String userId,
    required String sessionId,
    required String contextDate,
  }) async {
    final record = await _loadDismissals(userId);
    return record.contextDate == contextDate &&
        record.sessionIds.contains(sessionId);
  }

  @override
  Future<void> markDismissed({
    required String userId,
    required String sessionId,
    required String contextDate,
  }) async {
    final record = await _loadDismissals(userId);
    final sameContextDate = record.contextDate == contextDate;
    final sessionIds = sameContextDate ? {...record.sessionIds} : <String>{};
    sessionIds.add(sessionId);
    await _saveDismissals(
      userId: userId,
      record: _ProactiveDismissalRecord(
        contextDate: contextDate,
        sessionIds: sessionIds,
      ),
    );
  }

  Future<_ProactiveDismissalRecord> _loadDismissals(String userId) async {
    final encoded = await _preferences.getString('$_dismissalPrefix.$userId');
    if (encoded == null) {
      return const _ProactiveDismissalRecord(contextDate: '', sessionIds: {});
    }

    try {
      final data = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      final contextDate = data['context_date'];
      final sessionIds = data['session_ids'];
      if (contextDate is! String || sessionIds is! List) {
        throw const FormatException('Invalid proactive dismissals');
      }
      return _ProactiveDismissalRecord(
        contextDate: contextDate,
        sessionIds: sessionIds.whereType<String>().toSet(),
      );
    } on Object {
      return const _ProactiveDismissalRecord(contextDate: '', sessionIds: {});
    }
  }

  Future<void> _saveDismissals({
    required String userId,
    required _ProactiveDismissalRecord record,
  }) {
    return _preferences.setString(
      '$_dismissalPrefix.$userId',
      jsonEncode({
        'context_date': record.contextDate,
        'session_ids': record.sessionIds.toList(growable: false),
      }),
    );
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

class _ProactiveDismissalRecord {
  const _ProactiveDismissalRecord({
    required this.contextDate,
    required this.sessionIds,
  });

  final String contextDate;
  final Set<String> sessionIds;
}
