import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'public_holiday.dart';

final publicHolidayRegionPreferenceStoreProvider =
    Provider<PublicHolidayRegionPreferenceStore>((ref) {
      return SharedPreferencesPublicHolidayRegionPreferenceStore();
    });

abstract interface class PublicHolidayRegionPreferenceStore {
  Future<PublicHolidayRegion?> read({required String userId});

  Future<void> write({
    required String userId,
    required PublicHolidayRegion region,
  });

  Future<void> clearForUser(String userId);
}

class SharedPreferencesPublicHolidayRegionPreferenceStore
    implements PublicHolidayRegionPreferenceStore {
  SharedPreferencesPublicHolidayRegionPreferenceStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences ?? SharedPreferencesAsync();

  static const _keyPrefix = 'vinscent.calendar.public_holiday_region';

  final SharedPreferencesAsync _preferences;

  @override
  Future<PublicHolidayRegion?> read({required String userId}) async {
    final value = await _preferences.getString('$_keyPrefix.$userId');
    if (value == null) {
      return null;
    }
    return PublicHolidayRegion.fromStorageValue(value);
  }

  @override
  Future<void> write({
    required String userId,
    required PublicHolidayRegion region,
  }) {
    return _preferences.setString('$_keyPrefix.$userId', region.storageValue);
  }

  @override
  Future<void> clearForUser(String userId) {
    return _preferences.remove('$_keyPrefix.$userId');
  }
}
