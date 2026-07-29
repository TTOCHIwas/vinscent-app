import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile debug logging is guarded from release builds', () {
    final dartFiles =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    expect(dartFiles, isNotEmpty);

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        if (!_debugPrintCall.hasMatch(lines[index])) {
          continue;
        }

        final contextStart = math.max(0, index - 5);
        final precedingContext = lines.sublist(contextStart, index).join('\n');

        expect(
          precedingContext,
          contains('if (kDebugMode'),
          reason:
              '${file.path}:${index + 1} logs without a nearby '
              'kDebugMode guard.',
        );
      }
    }
  });
}

final _debugPrintCall = RegExp(r'\bdebugPrint(?:Stack)?\s*\(');
