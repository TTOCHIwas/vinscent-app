import 'package:flutter_riverpod/flutter_riverpod.dart';

final shellNavigationGuardProvider = Provider((ref) => ShellNavigationGuard());

class ShellNavigationGuard {
  final _registrations =
      <Object, ({String location, Future<bool> Function() confirm})>{};
  final _pending = <Object, Future<bool>>{};

  void register(
    Object owner,
    String location,
    Future<bool> Function() confirm,
  ) {
    _registrations.remove(owner);
    _registrations[owner] = (location: location, confirm: confirm);
  }

  void unregister(Object owner) {
    _registrations.remove(owner);
  }

  Future<bool> allows(String location) {
    for (final owner in _registrations.keys.toList().reversed) {
      final registration = _registrations[owner]!;
      if (registration.location == location) {
        return _pending[owner] ??= registration.confirm().whenComplete(() {
          _pending.remove(owner);
        });
      }
    }
    return Future.value(true);
  }
}
