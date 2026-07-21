import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/auth_sign_out_service.dart';

void main() {
  test('runs authenticated cleanup before signing out', () async {
    final events = <String>[];
    final service = AuthSignOutService(
      cleanup: _FakeAuthSignOutCleanup(() => events.add('cleanup')),
      signOut: () async => events.add('signOut'),
    );

    await service.execute();

    expect(events, ['cleanup', 'signOut']);
  });

  test('cleanup failure does not block signing out', () async {
    final events = <String>[];
    final service = AuthSignOutService(
      cleanup: _FakeAuthSignOutCleanup(() {
        events.add('cleanup');
        throw StateError('cleanup failed');
      }),
      signOut: () async => events.add('signOut'),
    );

    await service.execute();

    expect(events, ['cleanup', 'signOut']);
  });
}

class _FakeAuthSignOutCleanup implements AuthSignOutCleanup {
  const _FakeAuthSignOutCleanup(this.onRun);

  final void Function() onRun;

  @override
  Future<void> run() async => onRun();
}
