import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_change_source.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/safety/application/user_safety_realtime_controller.dart';
import 'package:vinscent/features/safety/data/user_safety_state_change_source.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test(
    'refreshes couple access and read models on a safety revision',
    () async {
      final repository = _FakeCoupleRepository()..current = activeCouple();
      final safetyChanges = _FakeUserSafetyStateChangeSource();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (ref, notifier) => AuthStatus.authenticated,
          ),
          profileControllerProvider.overrideWithBuild(
            (ref, notifier) async => _profile,
          ),
          coupleRepositoryProvider.overrideWithValue(repository),
          coupleChangeSourceProvider.overrideWithValue(
            const _SilentCoupleChangeSource(),
          ),
          userSafetyStateChangeSourceProvider.overrideWithValue(safetyChanges),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(safetyChanges.close);

      expect(await container.read(coupleControllerProvider.future), isNotNull);
      await container.read(userSafetyRealtimeControllerProvider.future);
      expect(safetyChanges.watchedUserId, _profile.id);

      repository.current = null;
      safetyChanges.emit(1);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(container.read(coupleControllerProvider).requireValue, isNull);
      expect(container.read(userSafetyRevisionProvider), 1);
    },
  );

  test('does not subscribe before authentication', () async {
    final safetyChanges = _FakeUserSafetyStateChangeSource();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthStatus.unauthenticated,
        ),
        userSafetyStateChangeSourceProvider.overrideWithValue(safetyChanges),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(safetyChanges.close);

    await container.read(userSafetyRealtimeControllerProvider.future);

    expect(safetyChanges.watchedUserId, isNull);
  });
}

class _FakeUserSafetyStateChangeSource implements UserSafetyStateChangeSource {
  final _controller = StreamController<int>.broadcast();
  String? watchedUserId;

  @override
  Stream<int> watch({required String userId}) {
    watchedUserId = userId;
    return _controller.stream;
  }

  void emit(int revision) => _controller.add(revision);

  Future<void> close() => _controller.close();
}

class _SilentCoupleChangeSource implements CoupleChangeSource {
  const _SilentCoupleChangeSource();

  @override
  Stream<void> watch({required String coupleId}) {
    return const Stream<void>.empty();
  }
}

class _FakeCoupleRepository implements CoupleRepository {
  Couple? current;

  @override
  Future<Couple?> fetchCurrentCouple() async => current;

  @override
  Future<Couple?> cancelInvite() => throw UnimplementedError();

  @override
  Future<Couple> createInvite() => throw UnimplementedError();

  @override
  Future<void> deleteDisconnectedArchiveNow() => throw UnimplementedError();

  @override
  Future<Couple> disconnectCouple() => throw UnimplementedError();

  @override
  Future<Couple> joinByCode(String inviteCode) => throw UnimplementedError();

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) =>
      throw UnimplementedError();

  @override
  Future<Couple> useDefaultCharacter() => throw UnimplementedError();
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: 'User',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
