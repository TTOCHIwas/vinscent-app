import 'dart:async';

import 'package:flutter/foundation.dart';
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
    _debugPushLog('Controller build started');

    ref.onDispose(() {
      _debugPushLog('Controller disposed');
      _tokenRefreshSubscription?.cancel();
    });

    final authStatus = ref.watch(authControllerProvider);
    _debugPushLog('Auth status: $authStatus');

    if (authStatus != AuthStatus.authenticated) {
      _debugPushLog('Token registration skipped: user is not authenticated');
      return;
    }

    final repository = ref.watch(pushTokenRepositoryProvider);

    try {
      _debugPushLog('Foreground notification configuration started');
      await repository.configureForegroundNotifications();
      _debugPushLog('Foreground notification configuration completed');
    } catch (error) {
      _debugPushLog('Foreground notification configuration failed: $error');
    }

    try {
      _debugPushLog('Current device token registration started');
      await repository.registerCurrentDeviceToken();
      _debugPushLog('Current device token registration completed');
    } catch (error) {
      _debugPushLog('Current device token registration failed: $error');
    }

    _tokenRefreshSubscription = repository.tokenRefreshes.listen((token) {
      _debugPushLog(
        'Token refresh received: prefix=${_tokenPrefix(token)}, '
        'length=${token.length}',
      );

      unawaited(
        repository
            .registerToken(token)
            .then((_) {
              _debugPushLog('Refreshed token registration completed');
            })
            .catchError((Object error) {
              _debugPushLog('Refreshed token registration failed: $error');
            }),
      );
    });
    _debugPushLog('Token refresh listener attached');
  }

  String _tokenPrefix(String token) {
    if (token.length <= 12) {
      return token;
    }

    return token.substring(0, 12);
  }

  void _debugPushLog(String message) {
    if (kDebugMode) {
      debugPrint('[push] $message');
    }
  }
}
