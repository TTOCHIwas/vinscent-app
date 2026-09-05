import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/date/app_date_policy.dart';
import 'public_holiday.dart';

final publicHolidayRepositoryProvider = Provider<PublicHolidayRepository>((
  ref,
) {
  return DefaultPublicHolidayRepository(
    remoteSource: const SupabasePublicHolidaySource(),
    bundledSource: const BundledPublicHolidaySource(),
    cache: SharedPreferencesPublicHolidayCache(),
  );
});

abstract interface class PublicHolidayRepository {
  Future<List<PublicHoliday>> fetchYear({
    required PublicHolidayRegion region,
    required int year,
  });
}

abstract interface class PublicHolidaySource {
  Future<List<PublicHoliday>> fetchYear({
    required PublicHolidayRegion region,
    required int year,
  });
}

class DefaultPublicHolidayRepository implements PublicHolidayRepository {
  const DefaultPublicHolidayRepository({
    required PublicHolidaySource remoteSource,
    required PublicHolidaySource bundledSource,
    required PublicHolidayCache cache,
    Duration cacheLifetime = const Duration(days: 7),
  }) : _remoteSource = remoteSource,
       _bundledSource = bundledSource,
       _cache = cache,
       _cacheLifetime = cacheLifetime;

  final PublicHolidaySource _remoteSource;
  final PublicHolidaySource _bundledSource;
  final PublicHolidayCache _cache;
  final Duration _cacheLifetime;

  @override
  Future<List<PublicHoliday>> fetchYear({
    required PublicHolidayRegion region,
    required int year,
  }) async {
    if (!region.isEnabled) {
      return const [];
    }

    final cached = await _cache.read(region: region, year: year);
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheLifetime) {
      return cached.holidays;
    }

    try {
      final remote = await _remoteSource.fetchYear(region: region, year: year);
      if (remote.isNotEmpty) {
        await _cache.write(
          region: region,
          year: year,
          entry: PublicHolidayCacheEntry(
            fetchedAt: DateTime.now(),
            holidays: remote,
          ),
        );
        return remote;
      }
    } catch (_) {}

    if (cached != null) {
      return cached.holidays;
    }
    return _bundledSource.fetchYear(region: region, year: year);
  }
}

class SupabasePublicHolidaySource implements PublicHolidaySource {
  const SupabasePublicHolidaySource();

  @override
  Future<List<PublicHoliday>> fetchYear({
    required PublicHolidayRegion region,
    required int year,
  }) async {
    if (!AppConfig.isSupabaseConfigured || !region.isEnabled) {
      return const [];
    }
    final startDate = DateTime(year);
    final endDate = DateTime(year, 12, 31);
    final data = await Supabase.instance.client
        .from('public_holidays')
        .select('holiday_date,name')
        .eq('country_code', region.storageValue)
        .eq('subdivision_code', '')
        .gte('holiday_date', formatCalendarDate(startDate))
        .lte('holiday_date', formatCalendarDate(endDate))
        .order('holiday_date')
        .timeout(AppConfig.supabaseRpcTimeout);
    return _groupRows(region, data);
  }
}

class BundledPublicHolidaySource implements PublicHolidaySource {
  const BundledPublicHolidaySource();

  static const _southKoreaAsset =
      'assets/calendar/kr_public_holidays_2025_2027.json';

  @override
  Future<List<PublicHoliday>> fetchYear({
    required PublicHolidayRegion region,
    required int year,
  }) async {
    if (region != PublicHolidayRegion.southKorea) {
      return const [];
    }
    final source = await rootBundle.loadString(_southKoreaAsset);
    final json = jsonDecode(source) as Map<String, Object?>;
    final rows = (json['holidays'] as List)
        .whereType<Map>()
        .map((value) => Map<String, Object?>.from(value))
        .where((row) => (row['date'] as String).startsWith('$year-'))
        .map((row) => {'holiday_date': row['date'], 'name': row['name']})
        .toList(growable: false);
    return _groupRows(region, rows);
  }
}

List<PublicHoliday> _groupRows(PublicHolidayRegion region, List<dynamic> rows) {
  final namesByDate = <DateTime, List<String>>{};
  for (final rawRow in rows.whereType<Map>()) {
    final row = Map<String, Object?>.from(rawRow);
    final date = parseCalendarDate(row['holiday_date'] as String?);
    final name = row['name'] as String?;
    if (date == null || name == null || name.trim().isEmpty) {
      continue;
    }
    namesByDate.putIfAbsent(date, () => []).add(name.trim());
  }
  return [
    for (final entry in namesByDate.entries)
      PublicHoliday(region: region, date: entry.key, names: entry.value),
  ]..sort((left, right) => left.date.compareTo(right.date));
}

class PublicHolidayCacheEntry {
  const PublicHolidayCacheEntry({
    required this.fetchedAt,
    required this.holidays,
  });

  final DateTime fetchedAt;
  final List<PublicHoliday> holidays;
}

abstract interface class PublicHolidayCache {
  Future<PublicHolidayCacheEntry?> read({
    required PublicHolidayRegion region,
    required int year,
  });

  Future<void> write({
    required PublicHolidayRegion region,
    required int year,
    required PublicHolidayCacheEntry entry,
  });
}

class SharedPreferencesPublicHolidayCache implements PublicHolidayCache {
  SharedPreferencesPublicHolidayCache({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _keyPrefix = 'vinscent.calendar.public_holidays.v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<PublicHolidayCacheEntry?> read({
    required PublicHolidayRegion region,
    required int year,
  }) async {
    final source = await _preferences.getString(_key(region, year));
    if (source == null) {
      return null;
    }
    try {
      final json = jsonDecode(source) as Map<String, Object?>;
      final fetchedAt = DateTime.parse(json['fetchedAt']! as String).toUtc();
      final rows = (json['holidays'] as List)
          .whereType<Map>()
          .map((value) => Map<String, Object?>.from(value))
          .toList(growable: false);
      return PublicHolidayCacheEntry(
        fetchedAt: fetchedAt,
        holidays: _groupRows(region, rows),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({
    required PublicHolidayRegion region,
    required int year,
    required PublicHolidayCacheEntry entry,
  }) {
    return _preferences.setString(
      _key(region, year),
      jsonEncode({
        'fetchedAt': entry.fetchedAt.toUtc().toIso8601String(),
        'holidays': [
          for (final holiday in entry.holidays)
            for (final name in holiday.names)
              {'holiday_date': formatCalendarDate(holiday.date), 'name': name},
        ],
      }),
    );
  }

  String _key(PublicHolidayRegion region, int year) {
    return '$_keyPrefix.${region.storageValue}.$year';
  }
}
