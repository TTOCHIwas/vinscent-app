import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/shell/application/shell_navigation_guard.dart';

void main() {
  test(
    'coalesces back and bottom navigation confirmation and respects cancel',
    () async {
      final guard = ShellNavigationGuard();
      final owner = Object();
      final answer = Completer<bool>();
      var calls = 0;
      guard.register(owner, '/ai', () {
        calls++;
        return answer.future;
      });
      final back = guard.allows('/ai');
      final tab = guard.allows('/ai');
      expect(calls, 1);
      expect(await guard.allows('/calendar'), isTrue);
      answer.complete(false);
      expect(await back, isFalse);
      expect(await tab, isFalse);
      guard.unregister(owner);
      expect(await guard.allows('/ai'), isTrue);
    },
  );
}
