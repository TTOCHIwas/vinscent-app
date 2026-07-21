abstract interface class AuthSignOutCleanup {
  Future<void> run();
}

class AuthSignOutService {
  const AuthSignOutService({
    required AuthSignOutCleanup cleanup,
    required Future<void> Function() signOut,
  }) : _cleanup = cleanup,
       _signOut = signOut;

  final AuthSignOutCleanup _cleanup;
  final Future<void> Function() _signOut;

  Future<void> execute() async {
    try {
      await _cleanup.run();
    } catch (_) {}

    await _signOut();
  }
}
