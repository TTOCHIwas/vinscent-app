import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_proactive_suggestion.dart';
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

  test('clears only the targeted user suggestion and dismissals', () async {
    final preferences = _MemoryPreferences();
    final store = SharedPreferencesAiProactiveSuggestionStore(
      preferences: preferences,
    );
    final suggestion = AiProactiveSuggestion(
      id: 'suggestion-1',
      text: '오늘의 추천',
      kind: AiProactiveSuggestionKind.dateIdea,
      generatedAt: DateTime.utc(2026, 7, 29),
      validUntil: DateTime.utc(2026, 7, 30),
      contextDate: '2026-07-29',
      hasCardToday: false,
    );
    await store.saveSuggestion('user-1', suggestion);
    await store.saveSuggestion('user-2', suggestion);
    await store.markDismissed(
      userId: 'user-1',
      sessionId: 'session-1',
      contextDate: '2026-07-29',
    );

    await store.clearForUser('user-1');

    expect(await store.loadSuggestion('user-1'), isNull);
    expect(await store.loadSuggestion('user-2'), isNotNull);
    expect(
      await store.hasDismissedInSession(
        userId: 'user-1',
        sessionId: 'session-1',
        contextDate: '2026-07-29',
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
