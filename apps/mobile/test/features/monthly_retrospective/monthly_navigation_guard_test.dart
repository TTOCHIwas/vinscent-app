import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/shell/application/shell_navigation_guard.dart';

void main() {
  test(
    'descendant ownership uses path boundaries and shares pending confirmation',
    () async {
      final guard = ShellNavigationGuard();
      final owner = Object();
      final answer = Completer<bool>();
      var calls = 0;
      guard.register(owner, '/monthly', () {
        calls++;
        return answer.future;
      }, includeDescendants: true);
      final parent = guard.allows('/monthly');
      final child = guard.allows('/monthly/record');
      expect(await guard.allows('/monthly-other'), isTrue);
      expect(calls, 1);
      answer.complete(false);
      expect(await parent, isFalse);
      expect(await child, isFalse);
      guard.unregister(owner);
      expect(await guard.allows('/monthly/record'), isTrue);
    },
  );

  test(
    'exact registrations do not acquire descendant routes by default',
    () async {
      final guard = ShellNavigationGuard();
      guard.register(Object(), '/ai', () async => false);
      expect(await guard.allows('/ai'), isFalse);
      expect(await guard.allows('/ai/ask'), isTrue);
    },
  );
  test('keeps AI draft guard after closing a calendar retrospective', () async {
    final guard = ShellNavigationGuard();
    final ai = Object();
    final calendar = Object();
    guard.register(ai, '/ai', () async => false);
    guard.register(calendar, '/calendar/monthly', () async => false);
    expect(await guard.allows('/ai'), isFalse);
    expect(await guard.allows('/calendar/monthly'), isFalse);
    guard.unregister(calendar);
    expect(await guard.allows('/ai'), isFalse);
    expect(await guard.allows('/calendar/monthly'), isTrue);
  });
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
