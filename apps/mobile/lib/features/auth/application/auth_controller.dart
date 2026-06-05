import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../notifications/data/push_token_repository.dart';
import 'auth_status.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    if (!AppConfig.isSupabaseConfigured) {
      return AuthStatus.unauthenticated;
    }

    final auth = Supabase.instance.client.auth;
    final subscription = auth.onAuthStateChange.listen(_handleAuthStateChange);
    ref.onDispose(subscription.cancel);

    return _statusFromSession(auth.currentSession);
  }

  Future<void> signOut() async {
    if (AppConfig.isSupabaseConfigured) {
      try {
        await ref
            .read(pushTokenRepositoryProvider)
            .deactivateCurrentDeviceToken();
      } catch (_) {
        // Sign-out should not be blocked by push token cleanup.
      }

      await Supabase.instance.client.auth.signOut();
    }

    state = AuthStatus.unauthenticated;
  }

  void _handleAuthStateChange(AuthState authState) {
    state = _statusFromSession(authState.session);
  }

  AuthStatus _statusFromSession(Session? session) {
    return session == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
  }
}
