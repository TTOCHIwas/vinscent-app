import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/presentation/ai_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_status.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/boot/presentation/boot_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/characters/presentation/character_editor_screen.dart';
import '../features/couple/application/couple_controller.dart';
import '../features/couple/data/couple.dart';
import '../features/couple/presentation/couple_entry_screen.dart';
import '../features/couple/presentation/couple_waiting_screen.dart';
import '../features/couple/presentation/relationship_start_date_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/questions/presentation/today_question_answer_screen.dart';
import '../features/questions/presentation/question_route_context.dart';
import '../features/recordings/presentation/recording_library_screen.dart';
import '../features/settings/presentation/couple_settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/story_loops/presentation/story_card_editor_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authControllerProvider);
  final profile = ref.watch(profileControllerProvider);
  final couple = ref.watch(coupleControllerProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final path = state.uri.path;
      final isBootRoute = path == '/boot';
      final isLoginRoute = path == '/login';
      final isOnboardingRoute = path == '/onboarding';
      final isCoupleEntryRoute = path == '/couple';
      final isCoupleWaitingRoute = path == '/couple/waiting';
      final isCoupleAnniversaryRoute = path == '/couple/anniversary';
      final isCoupleRoute =
          isCoupleEntryRoute ||
          isCoupleWaitingRoute ||
          isCoupleAnniversaryRoute;

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

            return couple.when(
              loading: () => isBootRoute ? null : '/boot',
              error: (error, stackTrace) => isBootRoute ? null : '/boot',
              data: (couple) {
                if (couple == null) {
                  return isCoupleEntryRoute ? null : '/couple';
                }

                return switch (couple.accessMode) {
                  CoupleAccessMode.pending =>
                    isCoupleWaitingRoute ? null : '/couple/waiting',
                  CoupleAccessMode.active =>
                    couple.relationshipStartDate == null
                        ? isCoupleAnniversaryRoute
                              ? null
                              : '/couple/anniversary'
                        : (isBootRoute ||
                              isLoginRoute ||
                              isOnboardingRoute ||
                              isCoupleRoute ||
                              path == '/')
                        ? '/home'
                        : null,
                  CoupleAccessMode.archivedReadOnly =>
                    (isBootRoute ||
                            isLoginRoute ||
                            isOnboardingRoute ||
                            isCoupleAnniversaryRoute ||
                            path == '/' ||
                            path == '/home/story' ||
                            path == '/home/question/edit')
                        ? '/home'
                        : null,
                };
              },
            );
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
      GoRoute(
        path: '/couple',
        name: 'couple',
        builder: (context, state) => const CoupleEntryScreen(),
      ),
      GoRoute(
        path: '/couple/waiting',
        name: 'coupleWaiting',
        builder: (context, state) => const CoupleWaitingScreen(),
      ),
      GoRoute(
        path: '/couple/anniversary',
        name: 'coupleAnniversary',
        builder: (context, state) => const RelationshipStartDateScreen(),
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
            path: '/home/story',
            name: 'storyCardEditor',
            builder: (context, state) => const StoryCardEditorScreen(),
          ),
          GoRoute(
            path: '/home/character',
            name: 'characterEditor',
            builder: (context, state) => const CharacterEditorScreen(),
          ),
          GoRoute(
            path: '/home/question',
            name: 'todayQuestionAnswer',
            builder: (context, state) {
              final dateQuery = state.uri.queryParameters['date'];
              final targetDate = parseQuestionRouteDate(dateQuery);
              return TodayQuestionAnswerScreen(
                targetDate: targetDate,
                hasInvalidTargetDate: hasInvalidQuestionRouteDate(dateQuery),
              );
            },
          ),
          GoRoute(
            path: '/home/question/edit',
            name: 'todayQuestionAnswerEdit',
            builder: (context, state) => TodayQuestionAnswerEditScreen(
              routeContext: QuestionRouteContext.fromEditUri(state.uri),
            ),
          ),
          GoRoute(
            path: '/home/recordings',
            name: 'recordingLibrary',
            builder: (context, state) => const RecordingLibraryScreen(),
          ),
          GoRoute(
            path: '/calendar',
            name: 'calendar',
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: '/calendar/question',
            name: 'calendarQuestionAnswer',
            builder: (context, state) {
              final dateQuery = state.uri.queryParameters['date'];
              final targetDate = parseQuestionRouteDate(dateQuery);
              return TodayQuestionAnswerScreen(
                targetDate: targetDate,
                hasInvalidTargetDate: hasInvalidQuestionRouteDate(dateQuery),
                backLocation: '/calendar',
              );
            },
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
          GoRoute(
            path: '/settings/notifications',
            name: 'notificationSettings',
            builder: (context, state) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: '/settings/couple',
            name: 'coupleSettings',
            builder: (context, state) => const CoupleSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
