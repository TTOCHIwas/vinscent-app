import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/presentation/ai_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_status.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/boot/presentation/boot_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/presentation/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authControllerProvider);
  final profile = ref.watch(profileControllerProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final path = state.uri.path;
      final isBootRoute = path == '/boot';
      final isLoginRoute = path == '/login';
      final isOnboardingRoute = path == '/onboarding';

      return switch (authStatus) {
        AuthStatus.checking => isBootRoute ? null : '/boot',
        AuthStatus.unauthenticated => isLoginRoute ? null : '/login',
        AuthStatus.authenticated => profile.when(
          loading: () => isBootRoute ? null : '/boot',
          error: (error, stackTrace) => isBootRoute ? null : '/boot',
          data: (profile) {
            if (profile == null) {
              return isOnboardingRoute ? null : '/onboarding';
            }

            return (isBootRoute ||
                    isLoginRoute ||
                    isOnboardingRoute ||
                    path == '/')
                ? '/home'
                : null;
          },
        ),
      };
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/boot',
        name: 'boot',
        builder: (context, state) => const BootScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/ai',
            name: 'ai',
            builder: (context, state) => const AiScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
