import 'package:flutter_test/flutter_test.dart';

import '../../tool/store_listing_copy_validator.dart';

void main() {
  test('parses the existing quoted store listing sections', () {
    final copy = StoreListingCopy.parse(_validSource);

    expect(copy.appName, '단짠');
    expect(copy.playShortDescription, '둘만의 기록');
    expect(copy.playFullDescription, '첫 번째 문단입니다.\n\n두 번째 문단입니다.');
    expect(copy.appStoreSubtitle, '카드와 목소리 기록');
    expect(copy.appStorePromotionalText, '둘의 오늘을 함께 남겨 보세요.');
    expect(copy.appStoreKeywords, '커플,연애,카드');
    expect(copy.appStoreDescription, '앱스토어 설명입니다.');
  });

  test('rejects text that exceeds official store limits', () {
    final copy = StoreListingCopy(
      appName: List.filled(31, '가').join(),
      playShortDescription: '둘만의 기록',
      playFullDescription: '설명',
      appStoreSubtitle: '카드와 목소리 기록',
      appStorePromotionalText: '둘의 오늘을 함께 남겨 보세요.',
      appStoreKeywords: List.filled(101, 'a').join(),
      appStoreDescription: '설명',
    );

    expect(
      const StoreListingCopyValidator().validate(copy),
      containsAll([
        'appName exceeds 30 characters.',
        'appStore.keywords exceeds 100 UTF-8 bytes.',
      ]),
    );
  });

  test('rejects multiline single-line fields and duplicate keywords', () {
    final copy = StoreListingCopy(
      appName: '단짠',
      playShortDescription: '둘만의\n기록',
      playFullDescription: '설명',
      appStoreSubtitle: '카드와 목소리 기록',
      appStorePromotionalText: '둘의 오늘을 함께 남겨 보세요.',
      appStoreKeywords: '커플,연애,커플',
      appStoreDescription: '설명',
    );

    expect(
      const StoreListingCopyValidator().validate(copy),
      containsAll([
        'googlePlay.shortDescription must be a single line.',
        'appStore.keywords contains duplicate keyword: 커플.',
      ]),
    );
  });

  test('requires one quoted value for every store field', () {
    expect(
      () => StoreListingCopy.parse(
        _validSource.replaceFirst('> 둘만의 기록', '둘만의 기록'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('### 짧은 설명'),
        ),
      ),
    );
    expect(
      () => StoreListingCopy.parse('$_validSource\n### 짧은 설명\n> 중복'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('must appear exactly once'),
        ),
      ),
    );
  });
}

const _validSource = '''
# 스토어 등록 문구

## 1. 공통 이름

앱 이름:

> 단짠

## 2. Google Play

### 짧은 설명

> 둘만의 기록

### 전체 설명

> 첫 번째 문단입니다.
>
> 두 번째 문단입니다.

## 3. App Store

### 부제

> 카드와 목소리 기록

### 프로모션 텍스트

> 둘의 오늘을 함께 남겨 보세요.

### 키워드

> 커플,연애,카드

### 설명

> 앱스토어 설명입니다.
''';
