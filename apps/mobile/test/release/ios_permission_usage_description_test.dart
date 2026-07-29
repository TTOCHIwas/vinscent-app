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
  });
}

const _permissionDescriptions = <String>[
  '커플과 짧은 녹음을 주고받기 위해 마이크 권한이 필요합니다.',
  '스토리 카드에 사진을 추가하기 위해 사진 보관함 권한이 필요합니다.',
  '완성한 카드를 사진 보관함에 저장하기 위해 사진 추가 권한이 필요합니다.',
  '스토리 카드에 사진을 추가하기 위해 카메라 권한이 필요합니다.',
  '현재 지역과 날씨에 어울리는 활동을 추천하기 위해 위치 권한이 필요합니다.',
];
