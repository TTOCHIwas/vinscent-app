import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_proactive_suggestion_store.dart';

void main() {
  test('records dismissal only for the targeted foreground session', () async {
    final store = SharedPreferencesAiProactiveSuggestionStore(
      preferences: _MemoryPreferences(),
    );

    await store.markDismissed(
      userId: 'user-1',
      sessionId: 'session-1',
      contextDate: '2026-07-24',
    );

    expect(
      await store.hasDismissedInSession(
        userId: 'user-1',
        sessionId: 'session-1',
        contextDate: '2026-07-24',
      ),
      isTrue,
    );
    expect(
      await store.hasDismissedInSession(
        userId: 'user-1',
        sessionId: 'session-2',
        contextDate: '2026-07-24',
      ),
      isFalse,
    );
  });

  test('starts dismissal history again on a new context date', () async {
    final store = SharedPreferencesAiProactiveSuggestionStore(
      preferences: _MemoryPreferences(),
    );

    await store.markDismissed(
      userId: 'user-1',
      sessionId: 'session-1',
      contextDate: '2026-07-24',
    );
    expect(
      await store.hasDismissedInSession(
        userId: 'user-1',
        sessionId: 'session-1',
        contextDate: '2026-07-25',
      ),
      isFalse,
    );
  });
}

class _MemoryPreferences implements AiProactiveSuggestionPreferences {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
