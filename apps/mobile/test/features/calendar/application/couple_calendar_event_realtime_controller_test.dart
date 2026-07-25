import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/calendar/application/couple_calendar_event_realtime_controller.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_change_source.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('coalesces a burst of calendar changes into one revision', () async {
    final changeSource = _FakeCalendarEventChangeSource();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthStatus.authenticated,
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(),
        ),
        coupleCalendarEventChangeSourceProvider.overrideWithValue(changeSource),
      ],
    );
    addTearDown(container.dispose);

    await container.read(coupleCalendarEventRealtimeControllerProvider.future);
    changeSource.emit();
    changeSource.emit();

    await _waitUntil(
      () => container.read(coupleCalendarEventRevisionProvider) == 1,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(changeSource.watchedCoupleId, 'couple-id');
    expect(container.read(coupleCalendarEventRevisionProvider), 1);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final timeoutAt = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(timeoutAt)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(condition(), isTrue);
}

class _FakeCalendarEventChangeSource
    implements CoupleCalendarEventChangeSource {
  final _controller = StreamController<void>();
  String? watchedCoupleId;

  void emit() {
    _controller.add(null);
  }

  @override
  Stream<void> watch({required String coupleId}) {
    watchedCoupleId = coupleId;
    return _controller.stream;
  }
}
