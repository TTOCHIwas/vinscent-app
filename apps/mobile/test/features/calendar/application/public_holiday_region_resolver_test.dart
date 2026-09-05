import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/public_holiday.dart';

void main() {
  const resolver = PublicHolidayRegionResolver();

  test('한국 기기 지역은 대한민국 공휴일을 기본으로 사용한다', () {
    expect(
      resolver.resolveDefault(const Locale('ko', 'KR')),
      PublicHolidayRegion.southKorea,
    );
  });

  test('한국 외 기기 지역은 공휴일 표시를 기본으로 끈다', () {
    expect(
      resolver.resolveDefault(const Locale('en', 'US')),
      PublicHolidayRegion.off,
    );
    expect(
      resolver.resolveDefault(const Locale('ko')),
      PublicHolidayRegion.off,
    );
  });
}
