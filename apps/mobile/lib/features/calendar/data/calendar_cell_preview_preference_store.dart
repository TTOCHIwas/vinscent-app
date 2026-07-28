import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calendar_cell_preview_mode.dart';

final calendarCellPreviewPreferenceStoreProvider =
    Provider<CalendarCellPreviewPreferenceStore>(
      (ref) => SharedPreferencesCalendarCellPreviewPreferenceStore(),
    );

abstract interface class CalendarCellPreviewPreferenceStore {
  Future<CalendarCellPreviewMode> read({required String userId});

  Future<void> write({
    required String userId,
    required CalendarCellPreviewMode mode,
  });

  Future<void> clearForUser(String userId);
}

class SharedPreferencesCalendarCellPreviewPreferenceStore
    implements CalendarCellPreviewPreferenceStore {
  SharedPreferencesCalendarCellPreviewPreferenceStore({
    CalendarCellPreviewPreferences? preferences,
  }) : _preferences =
           preferences ?? SharedPreferencesCalendarCellPreviewPreferences();

  static const _keyPrefix = 'vinscent.calendar.cell_preview_mode';

  final CalendarCellPreviewPreferences _preferences;

  @override
  Future<CalendarCellPreviewMode> read({required String userId}) async {
    final value = await _preferences.getString(_keyFor(userId));
    return CalendarCellPreviewMode.fromStorageValue(value);
  }

  @override
  Future<void> write({
    required String userId,
    required CalendarCellPreviewMode mode,
  }) {
    return _preferences.setString(_keyFor(userId), mode.storageValue);
  }

  @override
  Future<void> clearForUser(String userId) {
    return _preferences.remove(_keyFor(userId));
  }

  String _keyFor(String userId) => '$_keyPrefix.$userId';
}

abstract interface class CalendarCellPreviewPreferences {
  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

class SharedPreferencesCalendarCellPreviewPreferences
    implements CalendarCellPreviewPreferences {
  SharedPreferencesCalendarCellPreviewPreferences({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
