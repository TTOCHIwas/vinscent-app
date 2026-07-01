import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../auth_debug_log.dart';
import '../../notifications/data/push_token_repository.dart';
import 'auth_status.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthStatus>(
  AuthController.new,
);

class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    if (!AppConfig.isSupabaseConfigured) {
      debugAuthLog('auth controller initialized without supabase config');
      return AuthStatus.unauthenticated;
    }

    final auth = Supabase.instance.client.auth;
    final subscription = auth.onAuthStateChange.listen(_handleAuthStateChange);
    ref.onDispose(subscription.cancel);

    debugAuthLog(
      'auth controller initialized '
      'currentSessionUserId=${summarizeAuthValue(auth.currentSession?.user.id)}',
    );
    return _statusFromSession(auth.currentSession);
  }

  Future<void> signOut() async {
    if (AppConfig.isSupabaseConfigured) {
      debugAuthLog('sign-out requested');
      try {
        await ref
            .read(pushTokenRepositoryProvider)
            .deactivateCurrentDeviceToken();
      } catch (_) {
        // Sign-out should not be blocked by push token cleanup.
      }

      await Supabase.instance.client.auth.signOut();
    }

    debugAuthLog('sign-out completed');
    state = AuthStatus.unauthenticated;
  }

  void _handleAuthStateChange(AuthState authState) {
    debugAuthLog(
      'auth state changed '
      'sessionUserId=${summarizeAuthValue(authState.session?.user.id)}',
    );
    state = _statusFromSession(authState.session);
  }

  AuthStatus _statusFromSession(Session? session) {
    return session == null
        ? AuthStatus.unauthenticated
        : AuthStatus.authenticated;
  }
}
