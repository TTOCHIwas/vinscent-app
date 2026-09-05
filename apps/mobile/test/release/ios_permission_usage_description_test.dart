import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS permission descriptions explain each user-facing purpose', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

    for (final description in _permissionDescriptions) {
      expect(infoPlist, contains('<string>$description</string>'));
    }
    expect(
      infoPlist,
      isNot(contains('Save story cards to your photo library')),
    );
    expect(infoPlist, contains('<key>NSCalendarsUsageDescription</key>'));
    expect(
      infoPlist,
      contains('<key>NSCalendarsFullAccessUsageDescription</key>'),
    );
  });

  test('iOS device calendar bridge is registered in the Runner target', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(
      appDelegate,
      contains('VinscentDeviceCalendarBridgeRegistration.register('),
    );
    expect(
      appDelegate,
      contains('VinscentDeviceCalendarBridge.register(with: registrar)'),
    );
    expect(
      _occurrences(project, 'VinscentDeviceCalendarBridge.swift'),
      greaterThanOrEqualTo(3),
    );
  });

  test(
    'iOS device calendar bridge recovers events by marker and prior date',
    () {
      final bridge = File(
        'ios/Runner/VinscentDeviceCalendarBridge.swift',
      ).readAsStringSync();

      expect(bridge, contains('let previousEventDate = try optionalDate'));
      expect(
        bridge,
        contains('[eventDate, previousEventDate].compactMap { \$0 }'),
      );
      expect(bridge, contains('candidateDates: [eventDate]'));
      expect(bridge, contains('\$0.url?.absoluteString == marker'));
    },
  );
}

int _occurrences(String source, String pattern) {
  return pattern.allMatches(source).length;
}

const _permissionDescriptions = <String>[
  '커플과 짧은 녹음을 주고받기 위해 마이크 권한이 필요합니다.',
  '스토리 카드에 사진을 추가하기 위해 사진 보관함 권한이 필요합니다.',
  '완성한 카드를 사진 보관함에 저장하기 위해 사진 추가 권한이 필요합니다.',
  '스토리 카드에 사진을 추가하기 위해 카메라 권한이 필요합니다.',
  '단짠에서 만든 일정을 선택한 기기 캘린더에 추가하고 수정하거나 삭제하기 위해 캘린더 권한이 필요합니다.',
  '현재 지역과 날씨에 어울리는 활동을 추천하기 위해 위치 권한이 필요합니다.',
];
