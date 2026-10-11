import 'package:flutter_riverpod/flutter_riverpod.dart';

final shellNavigationGuardProvider = Provider((ref) => ShellNavigationGuard());

class ShellNavigationGuard {
  Object? _owner;
  String? _location;
  Future<bool> Function()? _confirm;
  Future<bool>? _pending;

  void register(Object owner, String location, Future<bool> Function() confirm) {
    _owner = owner;
    _location = location;
    _confirm = confirm;
  }

  void unregister(Object owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    _location = null;
    _confirm = null;
  }

  Future<bool> allows(String location) {
    if (_confirm == null || location != _location) return Future.value(true);
    return _pending ??= _confirm!().whenComplete(() => _pending = null);
  }
}
