import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/settings/application/notification_preferences_controller.dart';
import 'package:vinscent/features/settings/data/notification_preferences.dart';
import 'package:vinscent/features/settings/presentation/notification_settings_screen.dart';

void main() {
  testWidgets('알림 항목을 하나의 그룹 목록으로 보여준다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPreferencesControllerProvider.overrideWithBuild(
            (ref, notifier) async => _preferences,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotificationSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final group = find.byKey(const Key('notification-settings-group'));

    expect(group, findsOneWidget);
    expect(
      find.descendant(of: group, matching: find.byType(SwitchListTile)),
      findsNWidgets(8),
    );
  });
}

final _preferences = NotificationPreferences(
  userId: 'user-id',
  partnerAnswerEnabled: true,
  dailyQuestionEnabled: true,
  reminderEnabled: true,
  coupleDisconnectEnabled: true,
  recordingEnabled: true,
  partnerStoryCardEnabled: true,
  coupleActivityEnabled: true,
  aiUpdatesEnabled: true,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
