import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/safety/application/ugc_safety_policy_controller.dart';
import 'package:vinscent/features/safety/data/ugc_safety_policy_repository.dart';
import 'package:vinscent/features/safety/data/ugc_safety_policy_status.dart';

void main() {
  test('does not request policy status before authentication', () async {
    final repository = _FakeUgcSafetyPolicyRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthStatus.unauthenticated,
        ),
        ugcSafetyPolicyRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(ugcSafetyPolicyControllerProvider.future),
      isNull,
    );
    expect(repository.fetchCount, 0);
  });

  test('loads the authenticated user policy status', () async {
    final repository = _FakeUgcSafetyPolicyRepository();
    final container = _authenticatedContainer(repository);
    addTearDown(container.dispose);

    final status = await container.read(
      ugcSafetyPolicyControllerProvider.future,
    );

    expect(status, _notAcceptedStatus);
    expect(repository.fetchCount, 1);
  });

  test('accepts the loaded server version and publishes the result', () async {
    final repository = _FakeUgcSafetyPolicyRepository();
    final container = _authenticatedContainer(repository);
    addTearDown(container.dispose);
    await container.read(ugcSafetyPolicyControllerProvider.future);

    final result = await container
        .read(ugcSafetyPolicyControllerProvider.notifier)
        .acceptCurrentPolicy();

    expect(repository.acceptedVersions, ['ugc-safety-v1']);
    expect(result, _acceptedStatus);
    expect(
      container.read(ugcSafetyPolicyControllerProvider).value,
      _acceptedStatus,
    );
  });

  test('coalesces concurrent acceptance attempts', () async {
    final acceptance = Completer<UgcSafetyPolicyStatus>();
    final repository = _FakeUgcSafetyPolicyRepository(
      acceptance: acceptance.future,
    );
    final container = _authenticatedContainer(repository);
    addTearDown(container.dispose);
    await container.read(ugcSafetyPolicyControllerProvider.future);
    final controller = container.read(
      ugcSafetyPolicyControllerProvider.notifier,
    );

    final first = controller.acceptCurrentPolicy();
    final second = controller.acceptCurrentPolicy();
    acceptance.complete(_acceptedStatus);

    expect(await first, _acceptedStatus);
    expect(await second, _acceptedStatus);
    expect(repository.acceptedVersions, ['ugc-safety-v1']);
  });
}

ProviderContainer _authenticatedContainer(
  UgcSafetyPolicyRepository repository,
) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWithBuild(
        (ref, notifier) => AuthStatus.authenticated,
      ),
      ugcSafetyPolicyRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeUgcSafetyPolicyRepository implements UgcSafetyPolicyRepository {
  _FakeUgcSafetyPolicyRepository({this.acceptance});

  final Future<UgcSafetyPolicyStatus>? acceptance;
  var fetchCount = 0;
  final acceptedVersions = <String>[];

  @override
  Future<UgcSafetyPolicyStatus> fetchStatus() async {
    fetchCount += 1;
    return _notAcceptedStatus;
  }

  @override
  Future<UgcSafetyPolicyStatus> accept({required String policyVersion}) async {
    acceptedVersions.add(policyVersion);
    return acceptance ?? _acceptedStatus;
  }
}

final _notAcceptedStatus = UgcSafetyPolicyStatus(
  policyVersion: 'ugc-safety-v1',
  isAccepted: false,
  acceptedAt: null,
);

final _acceptedStatus = UgcSafetyPolicyStatus(
  policyVersion: 'ugc-safety-v1',
  isAccepted: true,
  acceptedAt: DateTime.utc(2026, 7, 29),
);
