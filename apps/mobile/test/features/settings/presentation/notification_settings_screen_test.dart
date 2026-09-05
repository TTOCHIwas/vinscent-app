import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/notifications/data/notification_permission_repository.dart';
import 'package:vinscent/features/settings/application/notification_permission_controller.dart';
import 'package:vinscent/features/settings/application/notification_preferences_controller.dart';
import 'package:vinscent/features/settings/data/notification_preferences.dart';
import 'package:vinscent/features/settings/presentation/notification_settings_screen.dart';

void main() {
  testWidgets('알림 항목을 사용자 작업에 맞는 그룹으로 나누어 보여준다', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPreferencesControllerProvider.overrideWithBuild(
            (ref, notifier) async => _preferences,
          ),
          notificationPermissionControllerProvider.overrideWithBuild(
            (ref, notifier) async => NotificationPermissionStatus.denied,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotificationSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('notification-settings-card-question-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notification-settings-recording-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notification-settings-couple-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('notification-settings-character-group')),
      findsOneWidget,
    );
    expect(find.byType(SwitchListTile), findsNWidgets(8));
    for (final toggle in tester.widgetList<SwitchListTile>(
      find.byType(SwitchListTile),
    )) {
      expect(toggle.activeTrackColor, AppColors.controlActive);
      expect(toggle.activeThumbColor, AppColors.onControlActive);
    }
    expect(find.text('상대가 카드를 올렸을 때'), findsOneWidget);
    expect(find.text('새 질문이 도착했을 때'), findsOneWidget);
    expect(find.text('캐릭터가 전하는 소식'), findsOneWidget);
    expect(find.text('기기 알림이 꺼져 있어요'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '설정 열기'), findsOneWidget);
  });

  testWidgets('기기 알림 허용 상태의 완료 표시에는 중립색을 사용한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationPreferencesControllerProvider.overrideWithBuild(
            (ref, notifier) async => _preferences,
          ),
          notificationPermissionControllerProvider.overrideWithBuild(
            (ref, notifier) async => NotificationPermissionStatus.enabled,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotificationSettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final completedIcon = tester.widget<Icon>(
      find.byIcon(Icons.check_circle_outline_rounded),
    );

    expect(completedIcon.color, AppColors.selection);
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
