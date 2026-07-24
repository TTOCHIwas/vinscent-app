import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_proactive_suggestion_store.dart';

void main() {
  test(
    'limits proactive impressions to three foreground sessions per day',
    () async {
      final store = SharedPreferencesAiProactiveSuggestionStore(
        preferences: _MemoryPreferences(),
      );

      for (var index = 1; index <= 3; index++) {
        final sessionId = 'session-$index';
        expect(
          await store.canShow(
            userId: 'user-1',
            sessionId: sessionId,
            contextDate: '2026-07-24',
          ),
          isTrue,
        );
        await store.markShown(
          userId: 'user-1',
          sessionId: sessionId,
          contextDate: '2026-07-24',
        );
      }

      expect(
        await store.canShow(
          userId: 'user-1',
          sessionId: 'session-4',
          contextDate: '2026-07-24',
        ),
        isFalse,
      );
      expect(
        await store.canShow(
          userId: 'user-1',
          sessionId: 'session-4',
          contextDate: '2026-07-25',
        ),
        isTrue,
      );
    },
  );

  test('does not count the same foreground session twice', () async {
    final store = SharedPreferencesAiProactiveSuggestionStore(
      preferences: _MemoryPreferences(),
    );

    await store.markShown(
      userId: 'user-1',
      sessionId: 'session-1',
      contextDate: '2026-07-24',
    );

    expect(
      await store.hasShownInSession(userId: 'user-1', sessionId: 'session-1'),
      isTrue,
    );
    expect(
      await store.canShow(
        userId: 'user-1',
        sessionId: 'session-1',
        contextDate: '2026-07-24',
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
