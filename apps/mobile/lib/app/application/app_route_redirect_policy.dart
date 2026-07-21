import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_status.dart';
import '../../features/couple/data/couple.dart';
import '../../features/profile/data/user_profile.dart';

class AppRouteRedirectPolicy {
  const AppRouteRedirectPolicy._();

  static String? resolve({
    required String path,
    required AuthStatus authStatus,
    required AsyncValue<UserProfile?> profile,
    required AsyncValue<Couple?> couple,
  }) {
    final isBootRoute = path == '/boot';
    final isLoginRoute = path == '/login';
    final isOnboardingRoute = path == '/onboarding';
    final isCoupleEntryRoute = path == '/couple';
    final isCoupleWaitingRoute = path == '/couple/waiting';
    final isCoupleAnniversaryRoute = path == '/couple/anniversary';
    final isCoupleCharacterRoute = path == '/couple/character';
    final isCoupleSetupWaitingRoute = path == '/couple/setup/waiting';
    final isCoupleRoute =
        isCoupleEntryRoute ||
        isCoupleWaitingRoute ||
        isCoupleAnniversaryRoute ||
        isCoupleCharacterRoute ||
        isCoupleSetupWaitingRoute;

    return switch (authStatus) {
      AuthStatus.checking => isBootRoute ? null : '/boot',
      AuthStatus.unauthenticated => isLoginRoute ? null : '/login',
      AuthStatus.authenticated => profile.when(
        loading: () => isBootRoute ? null : '/boot',
        error: (_, _) => isBootRoute ? null : '/boot',
        data: (profile) {
          if (profile == null) {
            return isOnboardingRoute ? null : '/onboarding';
          }

          return couple.when(
            loading: () => isBootRoute ? null : '/boot',
            error: (_, _) => isBootRoute ? null : '/boot',
            data: (couple) {
              if (couple == null) {
                return isCoupleEntryRoute ? null : '/couple';
              }

              return switch (couple.accessMode) {
                CoupleAccessMode.pending =>
                  isCoupleWaitingRoute ? null : '/couple/waiting',
                CoupleAccessMode.active => _resolveActiveCouple(
                  path: path,
                  profile: profile,
                  couple: couple,
                  isBootRoute: isBootRoute,
                  isLoginRoute: isLoginRoute,
                  isOnboardingRoute: isOnboardingRoute,
                  isCoupleRoute: isCoupleRoute,
                  isCoupleAnniversaryRoute: isCoupleAnniversaryRoute,
                  isCoupleCharacterRoute: isCoupleCharacterRoute,
                  isCoupleSetupWaitingRoute: isCoupleSetupWaitingRoute,
                ),
                CoupleAccessMode.archivedReadOnly =>
                  (isBootRoute ||
                          isLoginRoute ||
                          isOnboardingRoute ||
                          isCoupleRoute ||
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
  }

  static String? _resolveActiveCouple({
    required String path,
    required UserProfile profile,
    required Couple couple,
    required bool isBootRoute,
    required bool isLoginRoute,
    required bool isOnboardingRoute,
    required bool isCoupleRoute,
    required bool isCoupleAnniversaryRoute,
    required bool isCoupleCharacterRoute,
    required bool isCoupleSetupWaitingRoute,
  }) {
    final setupIncomplete =
        couple.relationshipStartDate == null || couple.isCharacterSetupPending;
    final isSetupOwner = couple.isInitialSetupOwner(profile.id);

    if (setupIncomplete && !isSetupOwner) {
      return isCoupleSetupWaitingRoute ? null : '/couple/setup/waiting';
    }
    if (couple.relationshipStartDate == null) {
      return isCoupleAnniversaryRoute ? null : '/couple/anniversary';
    }
    if (couple.isCharacterSetupPending) {
      return isCoupleCharacterRoute ? null : '/couple/character';
    }

    return (isBootRoute ||
            isLoginRoute ||
            isOnboardingRoute ||
            isCoupleRoute ||
            path == '/')
        ? '/home'
        : null;
  }
}
