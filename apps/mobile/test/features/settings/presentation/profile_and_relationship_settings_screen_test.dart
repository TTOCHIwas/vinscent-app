import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/application/relationship_start_date_editor_controller.dart';
import 'package:vinscent/features/couple/application/relationship_start_date_editor_state.dart';
import 'package:vinscent/features/profile/application/profile_display_name_editor_controller.dart';
import 'package:vinscent/features/profile/application/profile_display_name_editor_state.dart';
import 'package:vinscent/features/settings/presentation/profile_display_name_settings_screen.dart';
import 'package:vinscent/features/settings/presentation/relationship_start_date_settings_screen.dart';

void main() {
  testWidgets('만난 날 설정은 기존 날짜와 저장 동작을 한 화면에 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          relationshipStartDateEditorControllerProvider.overrideWithBuild(
            (ref, notifier) async => RelationshipStartDateEditorState(
              originalDate: DateTime(2026, 5, 30),
              selectedDate: DateTime(2026, 5, 30),
              latestAllowedDate: DateTime(2026, 7, 28),
            ),
          ),
        ],
        child: const MaterialApp(home: RelationshipStartDateSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026.05.30'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('relationship-start-date-save')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('relationship-start-date-field')));
    await tester.pumpAndSettle();
    expect(find.text('만난 날 선택'), findsOneWidget);
  });

  testWidgets('닉네임 설정은 변경된 유효한 이름에만 저장을 허용한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileDisplayNameEditorControllerProvider.overrideWithBuild(
            (ref, notifier) async => const ProfileDisplayNameEditorState(
              originalValue: '또치',
              value: '또치',
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProfileDisplayNameSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveFinder = find.byKey(const Key('profile-display-name-save'));
    expect(tester.widget<IconButton>(saveFinder).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('profile-display-name-field')),
      '초코',
    );
    await tester.pump();

    expect(tester.widget<IconButton>(saveFinder).onPressed, isNotNull);
  });
}
