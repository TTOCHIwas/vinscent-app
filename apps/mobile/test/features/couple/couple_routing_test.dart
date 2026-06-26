import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/app/app.dart';
import 'package:vinscent/features/auth/application/auth_controller.dart';
import 'package:vinscent/features/auth/application/auth_status.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/couple/presentation/couple_entry_screen.dart';
import 'package:vinscent/features/couple/presentation/couple_waiting_screen.dart';
import 'package:vinscent/features/couple/presentation/relationship_start_date_screen.dart';
import 'package:vinscent/features/home/presentation/home_screen.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';

import '../../support/couple_fixtures.dart';

void main() {
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

  testWidgets('asks active couples for relationship start date first', (
    tester,
  ) async {
    await _pumpApp(tester, couple: _activeCoupleWithoutDate);

    expect(find.byType(RelationshipStartDateScreen), findsOneWidget);
  });

  testWidgets('sends fully active couples to home', (tester) async {
    await _pumpApp(tester, couple: _activeCouple);

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, {required Couple? couple}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) => AuthStatus.authenticated,
        ),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
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

final _activeCouple = activeCouple(
  relationshipStartDate: DateTime(2026),
);
