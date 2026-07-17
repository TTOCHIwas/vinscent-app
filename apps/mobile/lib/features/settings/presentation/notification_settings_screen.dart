import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/notification_preferences_controller.dart';
import '../data/notification_preferences.dart';
import 'widgets/settings_group.dart';
import 'widgets/settings_page_layout.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesControllerProvider);

    return SettingsPageLayout(
      title: '알림 설정',
      onBackPressed: () => context.pop(),
      child: preferences.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, stackTrace) => _SettingsLoadError(
          onRetry: () => ref
              .read(notificationPreferencesControllerProvider.notifier)
              .refresh(),
        ),
        data: (preferences) =>
            _NotificationSettingsContent(preferences: preferences),
      ),
    );
  }
}

class _NotificationSettingsContent extends ConsumerWidget {
  const _NotificationSettingsContent({required this.preferences});

  final NotificationPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      notificationPreferencesControllerProvider.notifier,
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SettingsGroup(
          key: const Key('notification-settings-group'),
          children: [
            SettingsToggleRow(
              title: '상대 답변 완료',
              value: preferences.partnerAnswerEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(partnerAnswerEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '질문 생성 완료',
              value: preferences.dailyQuestionEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(dailyQuestionEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '상대 스토리 카드 업로드',
              value: preferences.partnerStoryCardEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(partnerStoryCardEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '미답변 리마인드',
              value: preferences.reminderEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(reminderEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '커플 연결 해제 알림',
              value: preferences.coupleDisconnectEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(coupleDisconnectEnabled: value),
                ),
              ),
            ),
            SettingsToggleRow(
              title: '녹음 알림',
              value: preferences.recordingEnabled,
              onChanged: (value) => _updatePreferences(
                context: context,
                update: controller.updatePreferences(
                  preferences.copyWith(recordingEnabled: value),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _updatePreferences({
    required BuildContext context,
    required Future<void> update,
  }) async {
    try {
      await update;
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림 설정을 저장하지 못했어요.')));
    }
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('설정을 불러오지 못했어요.', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 8),
          Text(
            '잠시 후 다시 시도해 주세요.',
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
