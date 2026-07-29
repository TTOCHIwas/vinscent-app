import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS widget gallery metadata uses the Korean product language', () {
    final source = File(
      'ios/VinscentWidgets/VinscentWidgets.swift',
    ).readAsStringSync();

    expect(source, contains('.configurationDisplayName("단짠 캐릭터")'));
    expect(source, contains('.configurationDisplayName("단짠 카드")'));
    expect(source, contains('name: "카드 기울기"'));
    expect(source, contains('@Parameter(title: "기울기"'));
    expect(
      source,
      isNot(contains('Play or record your shared couple message.')),
    );
    expect(source, isNot(contains("Show your partner's latest card.")));
    expect(source, isNot(contains('Card appearance')));
  });

  test('iOS widget audio intents use the Korean product language', () {
    final source = File(
      'ios/SharedWidgets/VinscentWidgetAudioIntents.swift',
    ).readAsStringSync();

    expect(source, contains('"위젯 녹음 시작 또는 종료"'));
    expect(source, contains('"위젯 녹음 재생 또는 정지"'));
    expect(source, isNot(contains('"Toggle widget recording"')));
    expect(source, isNot(contains('"Toggle widget playback"')));
  });
}
