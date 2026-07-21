import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_sign_out_service.dart';

final authSignOutCleanupProvider = Provider<AuthSignOutCleanup>((ref) {
  return const NoOpAuthSignOutCleanup();
});

class NoOpAuthSignOutCleanup implements AuthSignOutCleanup {
  const NoOpAuthSignOutCleanup();

  @override
  Future<void> run() async {}
}
