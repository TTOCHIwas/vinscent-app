import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/app.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/application/couple_flow_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/data/couple_repository.dart';
import 'package:vinscent/features/couple/presentation/couple_entry_screen.dart';
import 'package:vinscent/features/couple/presentation/couple_setup_waiting_screen.dart';
import 'package:vinscent/features/couple/presentation/couple_waiting_screen.dart';
import 'package:vinscent/features/couple/presentation/relationship_start_date_screen.dart';
import 'package:vinscent/features/characters/presentation/character_editor_screen.dart';
import 'package:vinscent/features/home/presentation/home_screen.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/safety/application/ugc_safety_policy_controller.dart';
import 'package:vinscent/features/safety/data/ugc_safety_policy_status.dart';
import 'package:vinscent/features/safety/presentation/ugc_safety_policy_screen.dart';

import '../../support/couple_fixtures.dart';
import '../../support/safety_fixtures.dart';

void main() {
  testWidgets('requires the safety policy before couple entry', (tester) async {
    await _pumpApp(
      tester,
      couple: null,
      ugcSafetyPolicy: pendingUgcSafetyPolicyStatus(),
    );

    expect(find.byType(UgcSafetyPolicyScreen), findsOneWidget);
  });

  testWidgets('sends profiled users without a couple to couple entry', (
    tester,
  ) async {
    await _pumpApp(tester, couple: null);

    expect(find.byType(CoupleEntryScreen), findsOneWidget);
  });

  testWidgets('sends pending couples to waiting screen', (tester) async {
    await _pumpApp(tester, couple: _pendingCouple);

    expect(find.byType(CoupleWaitingScreen), findsOneWidget);
  });

  testWidgets('asks the code-entering member for relationship start date', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      couple: activeCoupleWithoutDate(
        userAId: 'partner-id',
        userBId: _profile.id,
      ),
    );

    expect(find.byType(RelationshipStartDateScreen), findsOneWidget);
  });

  testWidgets(
    'cancels incomplete connection from the relationship date back action',
    (tester) async {
      final repository = _RelationshipSetupRepository(
        activeCoupleWithoutDate(userAId: 'partner-id', userBId: _profile.id),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (ref, notifier) => AuthStatus.authenticated,
          ),
          profileControllerProvider.overrideWithBuild(
            (ref, notifier) async => _profile,
          ),
          ugcSafetyPolicyControllerProvider.overrideWithBuild(
            (ref, notifier) async => acceptedUgcSafetyPolicyStatus(),
          ),
          coupleRepositoryProvider.overrideWithValue(repository),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VinscentApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('이전'));
      await tester.pumpAndSettle();
      expect(find.text('커플 연결 설정을 그만둘까?'), findsOneWidget);

      await tester.tap(find.byKey(const Key('app-confirmation-confirm')));
      await tester.pumpAndSettle();

      expect(repository.wasInitialSetupCancelled, isTrue);
      expect(find.byType(CoupleEntryScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets('keeps the inviter waiting while initial setup is incomplete', (
    tester,
  ) async {
    await _pumpApp(tester, couple: _activeCoupleWithoutDate);

    expect(find.byType(CoupleSetupWaitingScreen), findsOneWidget);
    expect(find.text('설정 중입니다.'), findsOneWidget);
  });

  testWidgets('asks the code-entering member to configure a character', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      couple: activeCouple(
        userAId: 'partner-id',
        userBId: _profile.id,
        characterSetupStatus: CoupleCharacterSetupStatus.pending,
      ),
    );

    expect(find.byType(CharacterEditorScreen), findsOneWidget);
    expect(find.text('건너뛰기'), findsOneWidget);
  });

  testWidgets(
    'continues legacy default setup from relationship date to character',
    (tester) async {
      final repository = _RelationshipSetupRepository(
        activeCoupleWithoutDate(
          userAId: 'partner-id',
          userBId: _profile.id,
          characterSetupStatus: CoupleCharacterSetupStatus.defaultCharacter,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (ref, notifier) => AuthStatus.authenticated,
          ),
          profileControllerProvider.overrideWithBuild(
            (ref, notifier) async => _profile,
          ),
          ugcSafetyPolicyControllerProvider.overrideWithBuild(
            (ref, notifier) async => acceptedUgcSafetyPolicyStatus(),
          ),
          coupleRepositoryProvider.overrideWithValue(repository),
          coupleCharacterControllerProvider.overrideWithBuild(
            (ref, notifier) async => null,
          ),
          todayControllerProvider.overrideWithBuild(
            (ref, notifier) => DateTime(2026, 7, 18),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const VinscentApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RelationshipStartDateScreen), findsOneWidget);

      final flow = container.read(coupleFlowControllerProvider.notifier);
      flow.updateRelationshipStartDate(DateTime(2026, 7, 1));
      await flow.saveRelationshipStartDate();
      await tester.pumpAndSettle();

      expect(repository.savedDate, DateTime(2026, 7, 1));
      expect(find.byType(CharacterEditorScreen), findsOneWidget);
      expect(find.text('건너뛰기'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    },
  );

  testWidgets('sends fully active couples to home', (tester) async {
    await _pumpApp(tester, couple: _activeCouple);

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Couple? couple,
  UgcSafetyPolicyStatus? ugcSafetyPolicy,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthStatus.authenticated,
        ),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        ugcSafetyPolicyControllerProvider.overrideWithBuild(
          (ref, notifier) async =>
              ugcSafetyPolicy ?? acceptedUgcSafetyPolicyStatus(),
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => couple,
        ),
      ],
      child: const VinscentApp(),
    ),
  );

  await tester.pumpAndSettle();
}

final _profile = UserProfile(
  id: 'user-id',
  displayName: 'User',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _pendingCouple = pendingCouple();

final _activeCoupleWithoutDate = activeCoupleWithoutDate();

final _activeCouple = activeCouple(relationshipStartDate: DateTime(2026));

class _RelationshipSetupRepository implements CoupleRepository {
  _RelationshipSetupRepository(this._couple);

  Couple? _couple;
  DateTime? savedDate;
  bool wasInitialSetupCancelled = false;

  @override
  Future<Couple?> fetchCurrentCouple() async => _couple;

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) async {
    savedDate = date;
    final couple = _couple!;
    _couple = activeCouple(
      userAId: couple.userAId,
      userBId: couple.userBId!,
      relationshipStartDate: date,
      characterSetupStatus: CoupleCharacterSetupStatus.pending,
    );
    return _couple!;
  }

  @override
  Future<Couple?> cancelInvite() async => null;

  @override
  Future<void> cancelInitialSetup() async {
    wasInitialSetupCancelled = true;
    _couple = null;
  }

  @override
  Future<Couple> createInvite() => throw UnsupportedError('Not used');

  @override
  Future<void> deleteDisconnectedArchiveNow() async {}

  @override
  Future<Couple> disconnectCouple() => throw UnsupportedError('Not used');

  @override
  Future<Couple> joinByCode(String inviteCode) =>
      throw UnsupportedError('Not used');

  @override
  Future<Couple> useDefaultCharacter() => throw UnsupportedError('Not used');
}
