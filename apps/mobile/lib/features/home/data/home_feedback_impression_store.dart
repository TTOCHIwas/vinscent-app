import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final homeFeedbackImpressionStoreProvider =
    Provider<HomeFeedbackImpressionStore>(
      (ref) => SharedPreferencesHomeFeedbackImpressionStore(),
    );

abstract interface class HomeFeedbackImpressionStore {
  Future<bool> hasShown({
    required String userId,
    required String dailyQuestionId,
  });

  Future<void> markShown({
    required String userId,
    required String dailyQuestionId,
  });
}

class SharedPreferencesHomeFeedbackImpressionStore
    implements HomeFeedbackImpressionStore {
  SharedPreferencesHomeFeedbackImpressionStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _keyPrefix = 'vinscent.home_feedback.last_shown';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> hasShown({
    required String userId,
    required String dailyQuestionId,
  }) async {
    return await _preferences.getString(_keyFor(userId)) == dailyQuestionId;
  }

  @override
  Future<void> markShown({
    required String userId,
    required String dailyQuestionId,
  }) {
    return _preferences.setString(_keyFor(userId), dailyQuestionId);
  }

  String _keyFor(String userId) => '$_keyPrefix.$userId';
}
