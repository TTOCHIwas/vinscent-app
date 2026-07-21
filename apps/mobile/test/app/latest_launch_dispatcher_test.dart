import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/application/latest_launch_dispatcher.dart';

void main() {
  test('keeps the latest launch pending until the app is ready', () async {
    var isReady = false;
    final handled = <String>[];
    final dispatcher = LatestLaunchDispatcher<String>(
      isReady: () => isReady,
      handle: (value) async {
        handled.add(value);
        return true;
      },
    );

    dispatcher.enqueue('/first');
    dispatcher.enqueue('/latest');
    await Future<void>.delayed(Duration.zero);
    expect(handled, isEmpty);

    isReady = true;
    await dispatcher.drain();
    expect(handled, ['/latest']);
  });

  test('drains a newer launch after the active handler completes', () async {
    final firstBarrier = Completer<void>();
    final handled = <String>[];
    final dispatcher = LatestLaunchDispatcher<String>(
      isReady: () => true,
      handle: (value) async {
        handled.add(value);
        if (value == '/first') {
          await firstBarrier.future;
        }
        return true;
      },
    );

    dispatcher.enqueue('/first');
    await Future<void>.delayed(Duration.zero);
    dispatcher.enqueue('/second');
    firstBarrier.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(handled, ['/first', '/second']);
  });

  test('retains a launch that the handler could not consume', () async {
    var canConsume = false;
    final handled = <String>[];
    final dispatcher = LatestLaunchDispatcher<String>(
      isReady: () => true,
      handle: (value) async {
        handled.add(value);
        return canConsume;
      },
    );

    dispatcher.enqueue('/pending');
    await Future<void>.delayed(Duration.zero);
    canConsume = true;
    await dispatcher.drain();

    expect(handled, ['/pending', '/pending']);
  });
}
