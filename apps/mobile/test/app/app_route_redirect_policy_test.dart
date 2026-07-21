import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/application/app_route_redirect_policy.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';

import '../support/couple_fixtures.dart';

void main() {
  group('AppRouteRedirectPolicy', () {
    test(
      'routes unresolved authentication and profile states through boot',
      () {
        expect(
          _resolve(authStatus: AuthStatus.checking, path: '/home'),
          '/boot',
        );
        expect(
          _resolve(authStatus: AuthStatus.checking, path: '/boot'),
          isNull,
        );
        expect(
          _resolve(authStatus: AuthStatus.unauthenticated, path: '/home'),
          '/login',
        );
        expect(_resolve(profile: const AsyncLoading(), path: '/home'), '/boot');
        expect(
          _resolve(
            profile: AsyncError(StateError('profile'), StackTrace.empty),
            path: '/home',
          ),
          '/boot',
        );
      },
    );

    test('routes incomplete account and couple states to their flow', () {
      expect(_resolve(profile: const AsyncData(null)), '/onboarding');
      expect(_resolve(couple: const AsyncLoading()), '/boot');
      expect(_resolve(couple: const AsyncData(null)), '/couple');
      expect(_resolve(couple: AsyncData(pendingCouple())), '/couple/waiting');
    });

    test('routes each member to the correct initial setup step', () {
      final ownerWithoutDate = activeCoupleWithoutDate(
        userAId: 'partner-id',
        userBId: _profile.id,
      );
      final waitingPartner = activeCoupleWithoutDate(
        userAId: _profile.id,
        userBId: 'partner-id',
      );
      final ownerWithoutCharacter = activeCouple(
        userAId: 'partner-id',
        userBId: _profile.id,
        characterSetupStatus: CoupleCharacterSetupStatus.pending,
      );

      expect(
        _resolve(couple: AsyncData(ownerWithoutDate)),
        '/couple/anniversary',
      );
      expect(
        _resolve(couple: AsyncData(waitingPartner)),
        '/couple/setup/waiting',
      );
      expect(
        _resolve(couple: AsyncData(ownerWithoutCharacter)),
        '/couple/character',
      );
    });

    test('keeps valid active routes and leaves setup routes for home', () {
      final couple = AsyncData<Couple?>(activeCouple());

      expect(_resolve(couple: couple, path: '/calendar'), isNull);
      expect(_resolve(couple: couple, path: '/couple/waiting'), '/home');
      expect(_resolve(couple: couple, path: '/'), '/home');
    });

    test('blocks archived couples from shared write routes', () {
      final couple = AsyncData<Couple?>(archivedReadOnlyCouple());

      expect(_resolve(couple: couple, path: '/home/story'), '/home');
      expect(_resolve(couple: couple, path: '/home/question/edit'), '/home');
      expect(_resolve(couple: couple, path: '/calendar'), isNull);
    });
  });
}

String? _resolve({
  String path = '/home',
  AuthStatus authStatus = AuthStatus.authenticated,
  AsyncValue<UserProfile?>? profile,
  AsyncValue<Couple?> couple = const AsyncData(null),
}) {
  return AppRouteRedirectPolicy.resolve(
    path: path,
    authStatus: authStatus,
    profile: profile ?? AsyncData(_profile),
    couple: couple,
  );
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: 'User',
  birthDate: DateTime(2026),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
