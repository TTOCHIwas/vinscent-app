import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/public_holiday.dart';
import 'package:vinscent/features/calendar/data/public_holiday_repository.dart';

void main() {
  test('유효한 캐시가 있으면 원격 조회 없이 반환한다', () async {
    final remote = _FakePublicHolidaySource();
    final bundled = _FakePublicHolidaySource();
    final repository = DefaultPublicHolidayRepository(
      remoteSource: remote,
      bundledSource: bundled,
      cache: _FakePublicHolidayCache(
        PublicHolidayCacheEntry(
          fetchedAt: DateTime.now(),
          holidays: [_holiday('광복절')],
        ),
      ),
    );

    final holidays = await repository.fetchYear(
      region: PublicHolidayRegion.southKorea,
      year: 2026,
    );

    expect(holidays.single.label, '광복절');
    expect(remote.fetchCount, 0);
    expect(bundled.fetchCount, 0);
  });

  test('원격 조회가 실패하면 만료된 캐시라도 사용한다', () async {
    final repository = DefaultPublicHolidayRepository(
      remoteSource: _FakePublicHolidaySource(error: Exception('offline')),
      bundledSource: _FakePublicHolidaySource(holidays: [_holiday('번들')]),
      cache: _FakePublicHolidayCache(
        PublicHolidayCacheEntry(
          fetchedAt: DateTime.now().subtract(const Duration(days: 30)),
          holidays: [_holiday('캐시')],
        ),
      ),
    );

    final holidays = await repository.fetchYear(
      region: PublicHolidayRegion.southKorea,
      year: 2026,
    );

    expect(holidays.single.label, '캐시');
  });

  test('캐시와 원격 데이터가 없으면 번들 공휴일을 사용한다', () async {
    final bundled = _FakePublicHolidaySource(holidays: [_holiday('개천절')]);
    final repository = DefaultPublicHolidayRepository(
      remoteSource: _FakePublicHolidaySource(),
      bundledSource: bundled,
      cache: _FakePublicHolidayCache(null),
    );

    final holidays = await repository.fetchYear(
      region: PublicHolidayRegion.southKorea,
      year: 2026,
    );

    expect(holidays.single.label, '개천절');
    expect(bundled.fetchCount, 1);
  });
}

PublicHoliday _holiday(String name) {
  return PublicHoliday(
    region: PublicHolidayRegion.southKorea,
    date: DateTime(2026, 8, 15),
    names: [name],
  );
}

class _FakePublicHolidaySource implements PublicHolidaySource {
  _FakePublicHolidaySource({this.holidays = const [], this.error});

  final List<PublicHoliday> holidays;
  final Object? error;
  int fetchCount = 0;

  @override
  Future<List<PublicHoliday>> fetchYear({
    required PublicHolidayRegion region,
    required int year,
  }) async {
    fetchCount += 1;
    if (error case final error?) {
      throw error;
    }
    return holidays;
  }
}

class _FakePublicHolidayCache implements PublicHolidayCache {
  _FakePublicHolidayCache(this.entry);

  PublicHolidayCacheEntry? entry;

  @override
  Future<PublicHolidayCacheEntry?> read({
    required PublicHolidayRegion region,
    required int year,
  }) async {
    return entry;
  }

  @override
  Future<void> write({
    required PublicHolidayRegion region,
    required int year,
    required PublicHolidayCacheEntry entry,
  }) async {
    this.entry = entry;
  }
}
