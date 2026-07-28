import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home/data/home_feedback_impression_store.dart';

void main() {
  test('clears only the targeted user feedback impression', () async {
    final preferences = _MemoryPreferences();
    final store = SharedPreferencesHomeFeedbackImpressionStore(
      preferences: preferences,
    );
    await store.markShown(userId: 'user-a', dailyQuestionId: 'question-a');
    await store.markShown(userId: 'user-b', dailyQuestionId: 'question-b');

    await store.clearForUser('user-a');

    expect(
      await store.hasShown(userId: 'user-a', dailyQuestionId: 'question-a'),
      isFalse,
    );
    expect(
      await store.hasShown(userId: 'user-b', dailyQuestionId: 'question-b'),
      isTrue,
    );
  });
}

class _MemoryPreferences implements HomeFeedbackImpressionPreferences {
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
