import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../data/push_token_repository.dart';

final pushTokenControllerProvider =
    AsyncNotifierProvider<PushTokenController, void>(PushTokenController.new);

class PushTokenController extends AsyncNotifier<void> {
  StreamSubscription<String>? _tokenRefreshSubscription;

  @override
  Future<void> build() async {
    ref.onDispose(() {
      _tokenRefreshSubscription?.cancel();
    });

    final authStatus = ref.watch(authControllerProvider);
    if (authStatus != AuthStatus.authenticated) {
      return;
    }

    final repository = ref.watch(pushTokenRepositoryProvider);
    await repository.configureForegroundNotifications();
    await repository.registerCurrentDeviceToken();

    _tokenRefreshSubscription = repository.tokenRefreshes.listen((token) {
      unawaited(repository.registerToken(token).catchError((_) {}));
    });
  }
}
