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
import 'package:vinscent/features/safety/application/user_block_service.dart';
import 'package:vinscent/features/safety/application/user_safety_realtime_controller.dart';
import 'package:vinscent/features/safety/data/user_block.dart';
import 'package:vinscent/features/safety/data/user_block_repository.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('blocks the partner and refreshes the couple boundary', () async {
    final coupleRepository = _FakeCoupleRepository()..current = activeCouple();
    late _FakeUserBlockRepository userBlockRepository;
    userBlockRepository = _FakeUserBlockRepository(
      onBlock: () => coupleRepository.current = null,
    );
    final container = _createContainer(
      coupleRepository: coupleRepository,
      userBlockRepository: userBlockRepository,
    );
    addTearDown(container.dispose);

    expect(await container.read(coupleControllerProvider.future), isNotNull);

    await container.read(userBlockServiceProvider).blockCurrentPartner();

    expect(userBlockRepository.blockCallCount, 1);
    expect(container.read(coupleControllerProvider).requireValue, isNull);
    expect(container.read(userSafetyRevisionProvider), 1);
  });

  test('unblocks only the selected user and refreshes safety reads', () async {
    final userBlockRepository = _FakeUserBlockRepository();
    final container = _createContainer(
      coupleRepository: _FakeCoupleRepository(),
      userBlockRepository: userBlockRepository,
    );
    addTearDown(container.dispose);

    await container.read(coupleControllerProvider.future);

    final wasUnblocked = await container
        .read(userBlockServiceProvider)
        .unblockUser('blocked-user-id');

    expect(wasUnblocked, isTrue);
    expect(userBlockRepository.unblockedUserId, 'blocked-user-id');
    expect(container.read(userSafetyRevisionProvider), 1);
  });

  test(
    'creates an explicit reconnect invite before entering waiting',
    () async {
      final coupleRepository = _FakeCoupleRepository();
      late _FakeUserBlockRepository userBlockRepository;
      userBlockRepository = _FakeUserBlockRepository(
        onReconnect: () => coupleRepository.current = pendingCouple(),
      );
      final container = _createContainer(
        coupleRepository: coupleRepository,
        userBlockRepository: userBlockRepository,
      );
      addTearDown(container.dispose);

      await container.read(coupleControllerProvider.future);

      await container
          .read(userBlockServiceProvider)
          .createReconnectInvite('archived-couple-id');

      expect(userBlockRepository.reconnectedCoupleId, 'archived-couple-id');
      expect(
        container.read(coupleControllerProvider).requireValue?.isPending,
        isTrue,
      );
    },
  );
}

ProviderContainer _createContainer({
  required CoupleRepository coupleRepository,
  required UserBlockRepository userBlockRepository,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWithBuild(
        (ref, notifier) => AuthStatus.authenticated,
      ),
      profileControllerProvider.overrideWithBuild(
        (ref, notifier) async => _profile,
      ),
      coupleRepositoryProvider.overrideWithValue(coupleRepository),
      coupleChangeSourceProvider.overrideWithValue(
        const _SilentCoupleChangeSource(),
      ),
      userBlockRepositoryProvider.overrideWithValue(userBlockRepository),
    ],
  );
}

class _FakeUserBlockRepository implements UserBlockRepository {
  _FakeUserBlockRepository({this.onBlock, this.onReconnect});

  final void Function()? onBlock;
  final void Function()? onReconnect;
  int blockCallCount = 0;
  String? unblockedUserId;
  String? reconnectedCoupleId;

  @override
  Future<void> blockCurrentPartner() async {
    blockCallCount += 1;
    onBlock?.call();
  }

  @override
  Future<void> createReconnectInvite(String coupleId) async {
    reconnectedCoupleId = coupleId;
    onReconnect?.call();
  }

  @override
  Future<List<BlockedUser>> fetchBlockedUsers() async => const [];

  @override
  Future<List<ReconnectableCoupleArchive>> fetchReconnectableArchives() async =>
      const [];

  @override
  Future<bool> unblockUser(String userId) async {
    unblockedUserId = userId;
    return true;
  }
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
