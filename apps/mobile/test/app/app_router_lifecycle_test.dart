import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/router.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';

import '../support/couple_fixtures.dart';

final _testAuthStatusProvider =
    NotifierProvider<_TestAuthStatusController, AuthStatus>(
      _TestAuthStatusController.new,
    );

void main() {
  test('keeps one GoRouter instance while redirect inputs change', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => ref.watch(_testAuthStatusProvider),
        ),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final firstRouter = container.read(appRouterProvider);

    container
        .read(_testAuthStatusProvider.notifier)
        .update(AuthStatus.authenticated);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(appRouterProvider), same(firstRouter));
  });
}

class _TestAuthStatusController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.unauthenticated;

  void update(AuthStatus nextStatus) {
    state = nextStatus;
  }
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: 'User',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
