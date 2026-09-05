import 'package:flutter/widgets.dart';

import '../../../core/date/app_date_policy.dart';

enum PublicHolidayRegion {
  off('off'),
  southKorea('KR');

  const PublicHolidayRegion(this.storageValue);

  final String storageValue;

  bool get isEnabled => this != PublicHolidayRegion.off;

  static PublicHolidayRegion fromStorageValue(String? value) {
    return values.firstWhere(
      (region) => region.storageValue == value,
      orElse: () => PublicHolidayRegion.off,
    );
  }
}

class PublicHolidayRegionResolver {
  const PublicHolidayRegionResolver();

  PublicHolidayRegion resolveDefault(Locale locale) {
    return locale.countryCode?.toUpperCase() == 'KR'
        ? PublicHolidayRegion.southKorea
        : PublicHolidayRegion.off;
  }
}

class PublicHoliday {
  PublicHoliday({
    required this.region,
    required DateTime date,
    required this.names,
  }) : date = calendarDateOnly(date),
       assert(names.isNotEmpty);

  final PublicHolidayRegion region;
  final DateTime date;
  final List<String> names;

  String get label => names.join(' · ');
}
