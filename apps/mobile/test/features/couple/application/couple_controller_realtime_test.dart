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

import '../../../support/couple_fixtures.dart';

void main() {
  test('refreshes the inviter when the pending couple changes', () async {
    final repository = _FakeCoupleRepository();
    final changeSource = _FakeCoupleChangeSource();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthStatus.authenticated,
        ),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        coupleRepositoryProvider.overrideWithValue(repository),
        coupleChangeSourceProvider.overrideWithValue(changeSource),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(changeSource.close);

    expect(await container.read(coupleControllerProvider.future), isNull);

    final pending = await container
        .read(coupleControllerProvider.notifier)
        .createInvite();
    expect(pending.isPending, isTrue);
    expect(changeSource.watchedCoupleId, pending.id);

    repository.currentCouple = activeCoupleWithoutDate();
    changeSource.emit();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final refreshed = container.read(coupleControllerProvider).requireValue;
    expect(refreshed?.isActive, isTrue);
    expect(refreshed?.userBId, 'partner-id');
  });
}

class _FakeCoupleChangeSource implements CoupleChangeSource {
  final _controller = StreamController<void>.broadcast();
  String? watchedCoupleId;

  @override
  Stream<void> watch({required String coupleId}) {
    watchedCoupleId = coupleId;
    return _controller.stream;
  }

  void emit() => _controller.add(null);

  Future<void> close() => _controller.close();
}

class _FakeCoupleRepository implements CoupleRepository {
  Couple? currentCouple;

  @override
  Future<Couple?> fetchCurrentCouple() async => currentCouple;

  @override
  Future<Couple> createInvite() async {
    currentCouple = pendingCouple();
    return currentCouple!;
  }

  @override
  Future<Couple> joinByCode(String inviteCode) => throw UnimplementedError();

  @override
  Future<Couple?> cancelInvite() => throw UnimplementedError();

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) =>
      throw UnimplementedError();

  @override
  Future<Couple> useDefaultCharacter() => throw UnimplementedError();

  @override
  Future<Couple> disconnectCouple() => throw UnimplementedError();

  @override
  Future<void> deleteDisconnectedArchiveNow() => throw UnimplementedError();
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: 'User',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
