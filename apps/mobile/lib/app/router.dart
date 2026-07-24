import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'application/app_router_refresh_notifier.dart';
import 'application/app_route_redirect_policy.dart';
import '../features/ai/presentation/ai_direct_question_screen.dart';
import '../features/ai/presentation/ai_memory_screen.dart';
import '../features/ai/presentation/ai_screen.dart';
import '../features/ai/presentation/ai_focused_question_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/boot/presentation/boot_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/characters/presentation/character_editor_screen.dart';
import '../features/couple/application/couple_controller.dart';
import '../features/couple/presentation/couple_entry_screen.dart';
import '../features/couple/presentation/couple_setup_waiting_screen.dart';
import '../features/couple/presentation/couple_waiting_screen.dart';
import '../features/couple/presentation/relationship_start_date_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/profile/application/profile_controller.dart';
import '../features/questions/presentation/today_question_answer_screen.dart';
import '../features/questions/presentation/question_route_context.dart';
import '../features/recordings/presentation/recording_library_screen.dart';
import '../features/recordings/presentation/recording_slot_artwork_editor_screen.dart';
import '../features/settings/presentation/couple_settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/shell/presentation/home_tab_frame.dart';
import '../features/shell/presentation/widgets/shell_root_back_scope.dart';
import '../features/story_loops/presentation/story_card_editor_screen.dart';

final appRouterRefreshNotifierProvider = Provider<AppRouterRefreshNotifier>((
  ref,
) {
  final notifier = AppRouterRefreshNotifier();
  ref.listen(authControllerProvider, (_, _) => notifier.refresh());
  ref.listen(profileControllerProvider, (_, _) => notifier.refresh());
  ref.listen(coupleControllerProvider, (_, _) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(appRouterRefreshNotifierProvider);

  final router = GoRouter(
    initialLocation: '/home',
    overridePlatformDefaultLocation: true,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => AppRouteRedirectPolicy.resolve(
      path: state.uri.path,
      authStatus: ref.read(authControllerProvider),
      profile: ref.read(profileControllerProvider),
      couple: ref.read(coupleControllerProvider),
    ),
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
      GoRoute(
        path: '/couple/character',
        name: 'coupleCharacterSetup',
        builder: (context, state) => const CharacterEditorScreen.initialSetup(),
      ),
      GoRoute(
        path: '/couple/setup/waiting',
        name: 'coupleSetupWaiting',
        builder: (context, state) => const CoupleSetupWaitingScreen(),
      ),
      GoRoute(
        path: '/home/story',
        name: 'storyCardEditor',
        builder: (context, state) => const StoryCardEditorScreen(),
      ),
      StatefulShellRoute.indexedStack(
        pageBuilder: (context, state, navigationShell) => MaterialPage<void>(
          key: state.pageKey,
          canPop: false,
          child: AppShell(
            location: state.uri.path,
            navigationShell: navigationShell,
            child: navigationShell,
          ),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const ShellRootBackScope.home(
                  child: HomeTabFrame(child: HomeScreen()),
                ),
                routes: [
                  GoRoute(
                    path: 'character',
                    redirect: (context, state) => '/settings/character',
                  ),
                  GoRoute(
                    path: 'question',
                    name: 'todayQuestionAnswer',
                    builder: (context, state) {
                      final dateQuery = state.uri.queryParameters['date'];
                      final targetDate = parseQuestionRouteDate(dateQuery);
                      return TodayQuestionAnswerScreen(
                        targetDate: targetDate,
                        hasInvalidTargetDate: hasInvalidQuestionRouteDate(
                          dateQuery,
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'todayQuestionAnswerEdit',
                        builder: (context, state) =>
                            TodayQuestionAnswerEditScreen(
                              routeContext: QuestionRouteContext.fromEditUri(
                                state.uri,
                              ),
                            ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'recordings',
                    name: 'recordingLibrary',
                    builder: (context, state) => const RecordingLibraryScreen(),
                    routes: [
                      GoRoute(
                        path: 'create/:slotIndex',
                        name: 'recordingSlotCreate',
                        builder: (context, state) =>
                            RecordingSlotArtworkEditorScreen.create(
                              slotIndex:
                                  int.tryParse(
                                    state.pathParameters['slotIndex'] ?? '',
                                  ) ??
                                  0,
                            ),
                      ),
                      GoRoute(
                        path: ':slotId/artwork',
                        name: 'recordingSlotArtworkEditor',
                        builder: (context, state) =>
                            RecordingSlotArtworkEditorScreen(
                              slotId: state.pathParameters['slotId']!,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                name: 'calendar',
                builder: (context, state) =>
                    const ShellRootBackScope.secondaryTab(
                      child: CalendarScreen(),
                    ),
                routes: [
                  GoRoute(
                    path: 'question',
                    name: 'calendarQuestionAnswer',
                    builder: (context, state) {
                      final dateQuery = state.uri.queryParameters['date'];
                      final targetDate = parseQuestionRouteDate(dateQuery);
                      return TodayQuestionAnswerScreen(
                        targetDate: targetDate,
                        hasInvalidTargetDate: hasInvalidQuestionRouteDate(
                          dateQuery,
                        ),
                        backLocation: '/calendar',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai',
                name: 'ai',
                builder: (context, state) =>
                    const ShellRootBackScope.secondaryTab(child: AiScreen()),
                routes: [
                  GoRoute(
                    path: 'focused',
                    name: 'aiFocusedQuestions',
                    builder: (context, state) =>
                        const AiFocusedQuestionScreen(),
                  ),
                  GoRoute(
                    path: 'ask',
                    name: 'aiDirectQuestion',
                    builder: (context, state) => const AiDirectQuestionScreen(),
                  ),
                  GoRoute(
                    path: 'memories',
                    name: 'aiMemories',
                    builder: (context, state) => const AiMemoryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      ShellRoute(
        pageBuilder: (context, state, child) => MaterialPage<void>(
          key: state.pageKey,
          child: AppShell(location: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'notifications',
                name: 'notificationSettings',
                builder: (context, state) => const NotificationSettingsScreen(),
              ),
              GoRoute(
                path: 'character',
                name: 'characterEditor',
                builder: (context, state) => const CharacterEditorScreen(),
              ),
              GoRoute(
                path: 'couple',
                name: 'coupleSettings',
                builder: (context, state) => const CoupleSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
