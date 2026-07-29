import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_action_button.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/safety/data/ugc_safety_policy_repository.dart';
import 'package:vinscent/features/safety/data/ugc_safety_policy_status.dart';
import 'package:vinscent/features/safety/presentation/ugc_safety_policy_screen.dart';

void main() {
  testWidgets('requires an explicit acknowledgement before acceptance', (
    tester,
  ) async {
    final repository = _FakeUgcSafetyPolicyRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (ref, notifier) => AuthStatus.authenticated,
          ),
          ugcSafetyPolicyRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: UgcSafetyPolicyScreen()),
      ),
    );
    await tester.pumpAndSettle();

    AppActionButton acceptButton() {
      return tester.widget<AppActionButton>(
        find.byKey(const Key('ugc-policy-accept-button')),
      );
    }

    expect(find.text('안전하게 함께 쓰기'), findsOneWidget);
    expect(acceptButton().enabled, isFalse);

    final acknowledgement = find.byKey(const Key('ugc-policy-acknowledgement'));
    await tester.ensureVisible(acknowledgement);
    await tester.tap(acknowledgement);
    await tester.pump();

    expect(acceptButton().enabled, isTrue);

    await tester.tap(find.byKey(const Key('ugc-policy-accept-button')));
    await tester.pumpAndSettle();

    expect(repository.acceptedVersions, ['ugc-safety-v1']);
  });
}

class _FakeUgcSafetyPolicyRepository implements UgcSafetyPolicyRepository {
  final acceptedVersions = <String>[];

  @override
  Future<UgcSafetyPolicyStatus> fetchStatus() async {
    return const UgcSafetyPolicyStatus(
      policyVersion: 'ugc-safety-v1',
      isAccepted: false,
      acceptedAt: null,
    );
  }

  @override
  Future<UgcSafetyPolicyStatus> accept({required String policyVersion}) async {
    acceptedVersions.add(policyVersion);
    return UgcSafetyPolicyStatus(
      policyVersion: policyVersion,
      isAccepted: true,
      acceptedAt: DateTime.utc(2026, 7, 29),
    );
  }
}
