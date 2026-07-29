import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final document = File(
    '../../docs/release/store-listing-copy-ko.md',
  ).readAsStringSync();
  final googlePlay = _between(
    document,
    start: '## 2. Google Play',
    end: '## 3. App Store',
  );
  final appStore = _between(
    document,
    start: '## 3. App Store',
    end: '## 4. 스크린샷 구성',
  );

  test('Google Play listing copy stays within metadata limits', () {
    final appName = _quotedValue(document, '## 1. 공통 이름');
    final shortDescription = _quotedValue(googlePlay, '### 짧은 설명');
    final fullDescription = _quotedValue(googlePlay, '### 전체 설명');

    expect(appName.runes.length, inInclusiveRange(1, 30));
    expect(shortDescription.runes.length, inInclusiveRange(1, 80));
    expect(fullDescription.runes.length, inInclusiveRange(1, 4000));
  });

  test('App Store listing copy stays within metadata limits', () {
    final appName = _quotedValue(document, '## 1. 공통 이름');
    final subtitle = _quotedValue(appStore, '### 부제');
    final promotionalText = _quotedValue(appStore, '### 프로모션 텍스트');
    final keywords = _quotedValue(appStore, '### 키워드');
    final description = _quotedValue(appStore, '### 설명');

    expect(appName.runes.length, inInclusiveRange(2, 30));
    expect(subtitle.runes.length, inInclusiveRange(1, 30));
    expect(promotionalText.runes.length, inInclusiveRange(1, 170));
    expect(utf8.encode(keywords).length, inInclusiveRange(1, 100));
    expect(description.runes.length, inInclusiveRange(1, 4000));
  });
}

String _between(String source, {required String start, required String end}) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);

  if (startIndex < 0 || endIndex < 0) {
    throw FormatException('Missing section boundary: $start -> $end');
  }
  return source.substring(startIndex, endIndex);
}

String _quotedValue(String source, String heading) {
  final headingIndex = source.indexOf(heading);
  if (headingIndex < 0) {
    throw FormatException('Missing heading: $heading');
  }

  final lines = source.substring(headingIndex + heading.length).split('\n');
  final quotedLines = <String>[];
  var started = false;

  for (final line in lines) {
    if (!line.startsWith('>')) {
      if (started) {
        break;
      }
      if (line.startsWith('#')) {
        throw FormatException('Expected block quote after $heading');
      }
      continue;
    }

    started = true;
    quotedLines.add(line.length > 1 && line[1] == ' ' ? line.substring(2) : '');
  }

  final value = quotedLines.join('\n').trim();
  if (value.isEmpty) {
    throw FormatException('Empty block quote after $heading');
  }
  return value;
}
